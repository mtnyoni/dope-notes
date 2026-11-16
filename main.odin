package main

import config "./appconfig"
import git_sync "./git-sync"
import media "./media"
import state "./state"
import assets "assets"
import buffer "buffer"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"
import font "font"
import markdown "markdown"
import clay "shared:clay"
import theme "theme"
import ui "ui"
import clay_ui "ui/clay"
import sdl "vendor:sdl3"

DEFAULT_WIN_W :: 1320
DEFAULT_WIN_H :: 640

SAVE_INTERVAL_MS :: 1000
SCROLL_SPEED :: 7.2
AUTO_SYNC_INTERVAL_NS :: 60 * 1_000_000_000
NO_VSYNC_FRAME_DELAY_MS :: 16
MIN_FRAME_DELTA :: 0.001
MAX_FRAME_DELTA :: 0.1


Face :: ^font.Font
Cursors :: WindowCursors
App_State :: state.AppState
Doc_Id :: string
Notes_Dir :: string
Frame_Events :: FrameEvents
Ui_Assets :: assets.Manager


Init_Stage :: enum {
    None,
    Window,
    Cursors,
    Clay,
    Font,
    Renderer,
    Media,
    Assets,
    Clay_Renderer,
    Notes_Dir,
    App_State,
    Editor,
    Ticker,
    Text_Input,
    Sync_Worker,
}

App :: struct {
    stage:                  Init_Stage,
    running:                bool,
    window:                 ^sdl.Window,
    toast: ui.ToastState,
    about_dialog: ui.AboutDialogState,
    settings_open:          bool,
    titlebar_clickable:     bool,
    cursors:                Cursors,
    clay_memory:            [^]u8,
    face:                   Face,
    renderer:               ^sdl.Renderer,
    image_media:            media.Manager,
    ui_assets:              Ui_Assets,
    clay_renderer:          clay_ui.Clay_Renderer,
    notes_dir:              Notes_Dir,
    app_state:              App_State,
    documents:              ui.EditorDocuments,
    empty_editor:           ui.EditorState,
    editor_state:           ^ui.EditorState,
    loaded_doc:             Doc_Id,
    last_saved:             string,
    ticker:                 Save_Ticker,
    ticker_thread:          ^sdl.Thread,
    sync_worker:            git_sync.GithubSyncWorker,
    github_sync_thread:     ^sdl.Thread,
    vsync_enabled:          bool,
    previous_frame:         u64,
    next_auto_sync:         u64,
    settings_menu_progress: f32,
    menu_sync_pending:      bool,
}


Save_Ticker :: struct {
    mutex:   ^sdl.Mutex,
    running: bool,
    pending: bool,
}

main :: proc() {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)
    defer mem.tracking_allocator_destroy(&track)

    app: App
    defer app_destroy(&app)
    if !app_init(&app) {return}

    for app.running {
        defer free_all(context.temp_allocator)
        app_frame(&app)
    }
}

app_init :: proc(app: ^App) -> bool {
    app_init_platform(app) or_return
    app_init_graphics(app) or_return
    app_init_notes(app) or_return
    app_init_editor(app)
    app_init_workers(app) or_return
    app.running = true
    return true
}

app_init_platform :: proc(app: ^App) -> bool {
    app.window = create_app_window(&app.titlebar_clickable)
    if app.window == nil {return false}
    app.stage = .Window

    app.cursors = create_window_cursors()
    app.stage = .Cursors

    app.clay_memory = init_clay_context(app.window)
    app.stage = .Clay

    app.face = font.open(assets.resource_path("font/Roboto-Regular.ttf"))
    if app.face == nil {
        fmt.eprintln("Could not load Dope Notes font")
        return false
    }
    app.stage = .Font
    clay.SetMeasureTextFunction(clay_ui.measure_text, app.face)
    return true
}

app_init_graphics :: proc(app: ^App) -> bool {
    app.renderer = create_sdl_renderer(app.window)
    if app.renderer == nil {return false}
    app.stage = .Renderer

    if !media.init(&app.image_media, app.renderer) {
        fmt.eprintln("Could not initialize image loading")
        return false
    }
    app.stage = .Media

    assets_ok: bool
    app.ui_assets, assets_ok = assets.load(app.renderer)
    if !assets_ok {return false}
    app.stage = .Assets

    assert(sdl.SetRenderLogicalPresentation(app.renderer, 0, 0, .DISABLED))
    app.clay_renderer = clay_ui.Clay_Renderer {
        font = app.face,
    }
    app.stage = .Clay_Renderer
    return true
}

app_init_notes :: proc(app: ^App) -> bool {
    storage_ok: bool
    app.notes_dir, storage_ok = prepare_notes_directory()
    if !storage_ok {return false}
    app.stage = .Notes_Dir

    notebooks, notebook_err := markdown.get_notes(app.notes_dir)
    if notebook_err != nil {
        fmt.eprintln("Could not load notebooks:", notebook_err)
        return false
    }

    if err := markdown.migrate_note_folders(notebooks[:]); err != nil {
        fmt.eprintln("Could not migrate note storage:", err)
        markdown.free_notebooks(notebooks)
        return false
    }

    app.app_state = state.make_app_state(notebooks, "Default")
    app.stage = .App_State
    return true
}

app_init_editor :: proc(app: ^App) {
    app.empty_editor = make_empty_editor(app.face)
    app.editor_state = open_initial_editor(app)
    app.loaded_doc = app.app_state.current_doc
    app.last_saved = snapshot_current_note(&app.app_state)
    app.stage = .Editor
}

app_init_workers :: proc(app: ^App) -> bool {
    app.ticker = save_ticker_init()
    app.ticker_thread = save_ticker_start(&app.ticker)
    app.stage = .Ticker

    if !start_text_input(app.window) {return false}
    app.stage = .Text_Input

    app.vsync_enabled = sdl.SetRenderVSync(app.renderer, 1)
    app.previous_frame = sdl.GetTicksNS()
    app.next_auto_sync = sdl.GetTicksNS()

    app.sync_worker = git_sync.GithubSyncWorker {
        mutex     = sdl.CreateMutex(),
        notes_dir = app.notes_dir,
    }
    assert(app.sync_worker.mutex != nil)
    app.stage = .Sync_Worker
    return true
}

app_frame :: proc(app: ^App) {
    app.titlebar_clickable = app.settings_open || app.about_dialog.open ||
        app.about_dialog.animation_progress > 0
    manual_sync := app.menu_sync_pending
    delta_seconds, sync_requested := app_begin_frame(app)

    events := poll_frame_events(app.editor_state, &app.image_media, app.about_dialog.open || app.about_dialog.animation_progress > 0)
    if events.quit {app.running = false}
    if events.dismiss_dialog {app.about_dialog.open = false}

    app_sync_and_notes(app, sync_requested || events.sync_requested, manual_sync || events.sync_requested)
    app_draw(app, events, delta_seconds)
    app.titlebar_clickable = app.settings_open || app.about_dialog.open ||
        app.about_dialog.animation_progress > 0
}

app_begin_frame :: proc(
    app: ^App,
) -> (
    delta_seconds: f32,
    sync_requested: bool,
) {
    sync_requested = app.menu_sync_pending
    app.menu_sync_pending = false

    if save_ticker_take_pending(&app.ticker) {app_save_focused_note(app)}

    now := sdl.GetTicksNS()
    if auto_sync_due(now, &app.next_auto_sync) {sync_requested = true}

    delta_seconds = clamp(
        f32(now - app.previous_frame) / 1e9,
        MIN_FRAME_DELTA,
        MAX_FRAME_DELTA,
    )
    app.previous_frame = now
    return
}

app_sync_and_notes :: proc(app: ^App, sync_requested: bool, manual: bool) {
    git_sync.update_github_sync(
        &app.sync_worker,
        &app.github_sync_thread,
        sync_requested,
        manual,
        app.window,
        &app.app_state,
        &app.documents,
        &app.editor_state,
        &app.empty_editor,
        &app.loaded_doc,
        &app.last_saved,
        app.face,
        &app.toast,
    )

    state.update_note_content(
        &app.app_state,
        app.loaded_doc,
        ui.editor_text(app.editor_state),
    )
    if app.app_state.new_note_requested {
        app.app_state.new_note_requested = false
        if err := state.create_note(&app.app_state); err != nil {
            fmt.eprintln("Could not create note:", err)
        }
    }
}

app_draw :: proc(app: ^App, events: Frame_Events, delta_seconds: f32) {
    frame := prepare_frame(app.window, app.renderer)
    update_window_cursor(
        app.window,
        &app.cursors,
        frame.mouse_x,
        frame.mouse_y,
        &app.titlebar_clickable,
    )

    update_selected_note(
        &app.app_state,
        &app.documents,
        &app.editor_state,
        &app.empty_editor,
        &app.loaded_doc,
        &app.last_saved,
        app.face,
    )

    app.editor_state.media = &app.image_media
    scroll_delta := events.scroll_delta
    clay.UpdateScrollContainers(
        false,
        {scroll_delta.x * SCROLL_SPEED, scroll_delta.y * SCROLL_SPEED},
        delta_seconds,
    )

    render_app_layout(
        app.window,
        app.renderer,
        &app.clay_renderer,
        &app.ui_assets,
        &app.app_state,
        app.editor_state,
        frame,
        scroll_delta,
        events.left_pressed,
        delta_seconds,
        {
            open = &app.settings_open,
            sync_pending = &app.menu_sync_pending,
            animation_progress = &app.settings_menu_progress,
            about = &app.about_dialog,
            toast = &app.toast,
        },
    )

    assert(sdl.RenderPresent(app.renderer))
    if !app.vsync_enabled {sdl.Delay(NO_VSYNC_FRAME_DELAY_MS)}
}

app_destroy :: proc(app: ^App) {
    ui.destroy_toast(&app.toast)
    if app.stage >= .Sync_Worker {
        sync_worker_stop(&app.sync_worker, app.github_sync_thread)
    }
    if app.stage >= .Text_Input {stop_text_input(app.window)}
    if app.stage >= .Ticker {
        save_ticker_stop(&app.ticker, app.ticker_thread)
        app_save_focused_note(app)
        sdl.DestroyMutex(app.ticker.mutex)
    }
    if app.stage >= .Editor {
        delete(app.last_saved)
        ui.editor_destroy_state(&app.empty_editor)
        ui.editor_close_documents(&app.documents)
    }
    if app.stage >= .App_State {
        markdown.free_notebooks(app.app_state.notebooks)
    }
    if app.stage >= .Notes_Dir {delete(app.notes_dir)}
    if app.stage >= .Clay_Renderer {
        clay_ui.destroy_clay_renderer(&app.clay_renderer)
    }
    if app.stage >= .Assets {assets.destroy(&app.ui_assets)}
    if app.stage >= .Media {media.destroy(&app.image_media)}
    if app.stage >= .Renderer {sdl.DestroyRenderer(app.renderer)}
    if app.stage >= .Font {font.close(app.face)}
    if app.stage >= .Clay {free(rawptr(app.clay_memory))}
    if app.stage >= .Cursors {destroy_window_cursors(&app.cursors)}
    if app.stage >= .Window {
        sdl.DestroyWindow(app.window)
        sdl.Quit()
    }
}

init_clay_context :: proc(window: ^sdl.Window) -> [^]u8 {
    width, height: i32
    assert(sdl.GetWindowSize(window, &width, &height))
    min_memory_size: c.size_t = cast(c.size_t)clay.MinMemorySize()
    memory := make([^]u8, min_memory_size)
    arena := clay.CreateArenaWithCapacityAndMemory(min_memory_size, memory)
    clay.Initialize(
        arena,
        {f32(width), f32(height)},
        {handler = clay_ui.errorHandler},
    )
    return memory
}

create_sdl_renderer :: proc(window: ^sdl.Window) -> ^sdl.Renderer {
    renderer := sdl.CreateRenderer(window, nil)
    if renderer == nil {
        fmt.eprintln("Renderer creation failed:", sdl.GetError())
        return nil
    }
    return renderer
}

start_text_input :: proc(window: ^sdl.Window) -> bool {
    if !sdl.StartTextInput(window) {
        fmt.eprintln("Could not start text input:", sdl.GetError())
        return false
    }
    return true
}

stop_text_input :: proc(window: ^sdl.Window) {
    if !sdl.StopTextInput(window) {
        fmt.eprintln("Could not stop text input:", sdl.GetError())
    }
}

make_empty_editor :: proc(face: Face) -> ui.EditorState {
    return ui.EditorState{buf = buffer.make_gap_buffer(64), font = face}
}

open_initial_editor :: proc(app: ^App) -> ^ui.EditorState {
    if note := state.current_note(&app.app_state); note != nil {
        return ui.editor_open_note(&app.documents, note, app.face)
    }
    return &app.empty_editor
}

snapshot_current_note :: proc(app_state: ^App_State) -> string {
    if note := state.current_note(app_state); note != nil {
        return strings.clone(string(note.content))
    }
    return ""
}

app_save_focused_note :: proc(app: ^App) {
    git_sync.save_focused_note(
        app.editor_state,
        app.loaded_doc,
        &app.last_saved,
    )
}

save_ticker_init :: proc() -> Save_Ticker {
    ticker := Save_Ticker {
        mutex   = sdl.CreateMutex(),
        running = true,
    }
    assert(ticker.mutex != nil)
    return ticker
}

save_ticker_start :: proc(ticker: ^Save_Ticker) -> ^sdl.Thread {
    thread := sdl.CreateThread(save_tick, "note-save-ticker", ticker)
    assert(thread != nil)
    return thread
}

save_tick :: proc "c" (data: rawptr) -> c.int {
    ticker := cast(^Save_Ticker)data
    for {
        sdl.Delay(SAVE_INTERVAL_MS)
        sdl.LockMutex(ticker.mutex)
        if !ticker.running {
            sdl.UnlockMutex(ticker.mutex)
            break
        }
        ticker.pending = true
        sdl.UnlockMutex(ticker.mutex)
    }
    return 0
}

save_ticker_take_pending :: proc(ticker: ^Save_Ticker) -> bool {
    sdl.LockMutex(ticker.mutex)
    defer sdl.UnlockMutex(ticker.mutex)
    pending := ticker.pending
    ticker.pending = false
    return pending
}

save_ticker_stop :: proc(ticker: ^Save_Ticker, thread: ^sdl.Thread) {
    sdl.LockMutex(ticker.mutex)
    ticker.running = false
    sdl.UnlockMutex(ticker.mutex)
    sdl.WaitThread(thread, nil)
}

auto_sync_due :: proc(now: u64, next_auto_sync: ^u64) -> bool {
    if config.github_repo() == "" || now < next_auto_sync^ {return false}
    next_auto_sync^ = now + AUTO_SYNC_INTERVAL_NS
    return true
}

sync_worker_stop :: proc(
    worker: ^git_sync.GithubSyncWorker,
    thread: ^sdl.Thread,
) {
    if thread != nil {sdl.WaitThread(thread, nil)}
    sdl.DestroyMutex(worker.mutex)
}
