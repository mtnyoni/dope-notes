package git_sync

import config "../appconfig"
import state "../state"
import ui "../ui"
import font "../font"
import markdown "../markdown"
import buffer "../buffer"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import sdl "vendor:sdl3"

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
    save_focused_note(editor_state^, loaded_doc^, last_saved)
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
}

sync_github_worker :: proc "c" (data: rawptr) -> c.int {
    context = runtime.default_context()
    worker := cast(^GithubSyncWorker)data
    success := sync_github(worker.notes_dir)
    free_all(context.temp_allocator)
    sdl.LockMutex(worker.mutex)
    worker.success = success
    worker.done = true
    sdl.UnlockMutex(worker.mutex)
    return 0
}

update_github_sync :: proc(
    worker: ^GithubSyncWorker,
    sync_thread: ^^sdl.Thread,
    requested: bool,
    app_state: ^state.AppState,
    documents: ^ui.EditorDocuments,
    editor_state: ^^ui.EditorState,
    empty_editor: ^ui.EditorState,
    loaded_doc: ^string,
    last_saved: ^string,
    face: ^font.Font,
) {
    sdl.LockMutex(worker.mutex)
    done := worker.done
    success := worker.success
    sdl.UnlockMutex(worker.mutex)
    if sync_thread^ != nil && done {
        sdl.WaitThread(sync_thread^, nil)
        sync_thread^ = nil
        if success {
            reload_synced_notes(
                worker.notes_dir, app_state, documents, editor_state,
                empty_editor, loaded_doc, last_saved, face,
            )
        } else {
            fmt.eprintln("GitHub sync failed; see details above")
        }
    }

    if requested && sync_thread^ == nil {
        save_focused_note(editor_state^, loaded_doc^, last_saved)
        sdl.LockMutex(worker.mutex)
        worker.done = false
        sdl.UnlockMutex(worker.mutex)
        sync_thread^ = sdl.CreateThread(
            sync_github_worker, "github-sync", worker,
        )
        if sync_thread^ == nil {
            fmt.eprintln("Could not start GitHub sync:", sdl.GetError())
        }
    }
}

run_sync_command :: proc(directory: string, command: []string) -> bool {
	state, stdout, stderr, err := os.process_exec(
		{working_dir = directory, command = command},
		context.temp_allocator,
	)
	if err != nil {
		fmt.eprintln("GitHub sync command failed:", command, err)
		return false
	}

	if state.exit_code != 0 {
		fmt.eprintln("GitHub sync command failed:", command, string(stderr), string(stdout))
		return false
	}
	return true
}

sync_github :: proc(notes_dir: string) -> bool {
	repo := config.github_repo()
	if repo == "" || strings.count(repo, "/") != 1 {
		fmt.eprintln("Set DOPE_NOTES_GITHUB_REPO=owner/repo to enable GitHub sync")
		return false
	}
	if !run_sync_command(notes_dir, {"gh", "auth", "status"}) do return false
	if !run_sync_command(notes_dir, {"gh", "repo", "view", repo, "--json", "nameWithOwner"}) do return false
	if !os.exists(fmt.tprintf("%s/.git", notes_dir)) {
		if !run_sync_command(notes_dir, {"git", "init"}) do return false
		if !run_sync_command(notes_dir, {"git", "branch", "-M", "main"}) do return false
		if !run_sync_command(notes_dir, {"git", "remote", "add", "origin", fmt.tprintf("https://github.com/%s.git", repo)}) do return false
	}
	remote_state, remote_url, _, remote_err := os.process_exec(
		{working_dir = notes_dir, command = {"git", "remote", "get-url", "origin"}},
		context.temp_allocator,
	)
	if remote_err != nil ||
	   remote_state.exit_code != 0 ||
	   strings.trim_space(string(remote_url)) != fmt.tprintf("https://github.com/%s.git", repo) {
		fmt.eprintln("Notes directory origin does not match DOPE_NOTES_GITHUB_REPO")
		return false
	}
	// GitHub CLI supplies Git's credentials through the active login.
	if !run_sync_command(notes_dir, {"gh", "auth", "setup-git"}) do return false
	if !run_sync_command(notes_dir, {"git", "add", "--", "."}) do return false
	change_state, _, _, change_err := os.process_exec(
		{working_dir = notes_dir, command = {"git", "diff", "--cached", "--quiet"}},
		context.temp_allocator,
	)
	if change_err != nil || change_state.exit_code > 1 do return false
	if change_state.exit_code == 1 {
		if !run_sync_command(notes_dir, {"git", "commit", "-m", "Sync notes"}) do return false
	}
	branch_state, remote_output, remote_error, branch_err := os.process_exec(
		{working_dir = notes_dir, command = {"git", "ls-remote", "--heads", "origin", "main"}},
		context.temp_allocator,
	)
	if branch_err != nil || branch_state.exit_code != 0 {
		fmt.eprintln("Could not inspect remote branch:", branch_err, string(remote_error))
		return false
	}
	if len(remote_output) > 0 {
		if !run_sync_command(notes_dir, {"git", "fetch", "origin", "main"}) do return false
		if !run_sync_command(notes_dir, {"git", "rebase", "origin/main"}) do return false
	}
	return run_sync_command(notes_dir, {"git", "push", "-u", "origin", "main"})
}
