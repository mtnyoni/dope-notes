package git_sync

import config "../appconfig"
import buffer "../buffer"
import font "../font"
import markdown "../markdown"
import state "../state"
import ui "../ui"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import sdl "vendor:sdl3"


SyncPreflight :: enum {
    Ready,
    AlreadySynced,
    Offline,
    Failed,
    NeedsSetup,
}


save_focused_note :: proc(
    ed: ^ui.EditorState,
    path: string,
    last_saved: ^string,
) {
    if path == "" || ed == nil {return}

    left, right := buffer.get_strings(&ed.buf)
    content := fmt.tprintf("%s%s", left, right)
    if content == last_saved^ {return}
    if err := os.write_entire_file(path, content); err != nil {
        fmt.eprintln("Could not save note:", path, err)
        return
    }

    delete(last_saved^)
    last_saved^ = strings.clone(content)
}


reload_synced_notes :: proc(
    notes_dir: string,
    app_state: ^state.AppState,
    documents: ^ui.EditorDocuments,
    editor_state: ^^ui.EditorState,
    empty_editor: ^ui.EditorState,
    loaded_doc: ^string,
    last_saved: ^string,
    face: ^font.Font,
) {
    fresh_notebooks, fresh_err := markdown.get_notes(notes_dir)
    if fresh_err != nil {
        fmt.eprintln(
            "GitHub sync completed, but could not reload notebooks:",
            fresh_err,
        )
        return
    }
    ui.editor_close_documents(documents)
    markdown.free_notebooks(app_state.notebooks)
    app_state^ = state.make_app_state(fresh_notebooks, "Default")
    editor_state^ = empty_editor
    loaded_doc^ = ""
    delete(last_saved^)
    last_saved^ = ""
    if note := state.current_note(app_state); note != nil {
        editor_state^ = ui.editor_open_note(documents, note, face)
        loaded_doc^ = note.path
        last_saved^ = strings.clone(string(note.content))
    }
    fmt.println("GitHub sync complete")
}

GithubSyncWorker :: struct {
    mutex:     ^sdl.Mutex,
    notes_dir: string,
    done:      bool,
    success:   bool,
    manual:    bool,
    result:    SyncPreflight,
    error:     [1024]u8,
}

sync_github_worker :: proc "c" (data: rawptr) -> c.int {
    context = runtime.default_context()
    worker := cast(^GithubSyncWorker)data
    result := SyncPreflight.Failed
    success := false
    settings, configured := config.load_github_settings()
    if !configured {result = .NeedsSetup; copy_text(worker.error[:], "Repository settings are missing or invalid")} else {
        token, error := load_token()
        if token ==
           "" {result = .NeedsSetup; copy_text(worker.error[:], error)} else {
            code := dn_sync(
                cstr(worker.notes_dir),
                cstr(
                    fmt.tprintf(
                        "https://github.com/%s.git",
                        settings.repository,
                    ),
                ),
                cstr(settings.branch),
                cstr(token),
                cstr(settings.author_name),
                cstr(settings.author_email),
                &worker.error[0],
                len(worker.error),
            )

            if code ==
               0 {success = true; result = .Ready} else if code == 1 {result = .AlreadySynced; fmt.println("Already synced")} else if code == -2 {
                result = .Offline
            } else if code == -3 {result = .NeedsSetup}

        }
    }
    if !success && result != .AlreadySynced {
        if worker.error[0] ==
           0 {copy_text(worker.error[:], "Unknown GitHub sync error")}

        fmt.eprintfln(
            "GitHub sync [%v] repo=%s branch=%s: %s",
            result,
            settings.repository,
            settings.branch,
            string(cstring(&worker.error[0])),
        )
    }

    free_all(context.temp_allocator)
    sdl.LockMutex(worker.mutex)
    worker.result = result
    worker.success = success
    worker.done = true
    sdl.UnlockMutex(worker.mutex)
    return 0
}

update_github_sync :: proc(
    worker: ^GithubSyncWorker,
    sync_thread: ^^sdl.Thread,
    requested: bool,
    manual: bool,
    app_state: ^state.AppState,
    documents: ^ui.EditorDocuments,
    editor_state: ^^ui.EditorState,
    empty_editor: ^ui.EditorState,
    loaded_doc: ^string,
    last_saved: ^string,
    face: ^font.Font,
    toast: ^ui.ToastState,
    setup: ^ui.GithubSetupState,
) {
    sdl.LockMutex(worker.mutex)
    if requested && manual && sync_thread^ != nil {worker.manual = true}
    done := worker.done
    success := worker.success
    result := worker.result
    was_manual := worker.manual
    sdl.UnlockMutex(worker.mutex)
    if sync_thread^ != nil && done {
        sdl.WaitThread(sync_thread^, nil)
        sync_thread^ = nil
        if was_manual && result == .NeedsSetup {
            setup.open = true
            setup.just_opened = true
            setup.phase = .Welcome
            if worker.error[0] !=
               0 {copy_text(setup.error[:], string(cstring(&worker.error[0])))}
        }

        if was_manual && result != .NeedsSetup {
            if success ||
               result ==
                   .AlreadySynced {ui.show_toast(toast, "Synced")} else if result == .Offline {ui.show_toast(toast, string(cstring(&worker.error[0])), .CircleExclamation)} else {ui.show_toast(toast, string(cstring(&worker.error[0])), .CircleExclamation)}
        }

        if success {
            reload_synced_notes(
                worker.notes_dir,
                app_state,
                documents,
                editor_state,
                empty_editor,
                loaded_doc,
                last_saved,
                face,
            )

        } else if result != .AlreadySynced && result != .Offline {
            fmt.eprintln(
                "GitHub sync failed:",
                string(cstring(&worker.error[0])),
            )
        }
    }

    if requested && sync_thread^ == nil {
        save_focused_note(editor_state^, loaded_doc^, last_saved)
        sdl.LockMutex(worker.mutex)
        worker.error = {}
        worker.manual = manual
        worker.done = false
        sdl.UnlockMutex(worker.mutex)
        sync_thread^ = sdl.CreateThread(
            sync_github_worker,
            "github-sync",
            worker,
        )
        if sync_thread^ == nil {
            fmt.eprintln("Could not start GitHub sync:", sdl.GetError())
        }
    }
}
