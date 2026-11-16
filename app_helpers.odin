package main

import config "./appconfig"
import git_sync "./git-sync"
import media "./media"
import state "./state"
import assets "assets"
import "core:fmt"
import "core:os"
import "core:strings"
import font "font"
import clay "shared:clay"
import ui "ui"
import clay_ui "ui/clay"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"

set_window_icon :: proc(window: ^sdl.Window) {
    icon := img.Load(assets.resource_path("packaging/icons/dope-notes.png"))
    when ODIN_OS == .Linux {
        if icon ==
           nil {icon = img.Load("/usr/share/icons/hicolor/512x512/apps/dope-notes.png")}
    }
    if icon != nil {
        _ = sdl.SetWindowIcon(window, icon)
        sdl.DestroySurface(icon)
    }

}

prepare_notes_directory :: proc() -> (string, bool) {
    data_home := os.get_env("XDG_DATA_HOME", context.temp_allocator)
    when ODIN_OS == .Windows {
        data_home = os.get_env("APPDATA", context.temp_allocator)
    }
    if data_home == "" {
        home := os.get_env("HOME", context.temp_allocator)
        when ODIN_OS == .Windows {
            home = os.get_env("USERPROFILE", context.temp_allocator)
        }
        if home == "" {
            fmt.eprintln("Cannot find user notes storage")
            return "", false
        }
        when ODIN_OS == .Windows {
            data_home = fmt.tprintf("%s/AppData/Roaming", home)
        } else {
            data_home = fmt.tprintf("%s/.local/share", home)
        }
    }
    // Sync uses this path after the frame's temporary allocator is cleared.
    notes_dir := strings.clone(config.notebooks_path(data_home))
    first_run := !os.exists(notes_dir)
    default_notebook := fmt.tprintf("%s/Default", notes_dir)
    if first_run {
        if err := os.make_directory_all(default_notebook); err != nil {
            fmt.eprintln("Could not create notes directory:", err)
            delete(notes_dir)
            return "", false
        }
        if err := os.write_entire_file(
            fmt.tprintf("%s/Welcome.md", default_notebook),
            "Hello there!\n",
        ); err != nil {
            fmt.eprintln("Could not create welcome note:", err)
            delete(notes_dir)
            return "", false
        }
    }
    return notes_dir, true
}

FrameEvents :: struct {
    scroll_delta:   clay.Vector2,
    left_pressed:   bool,
    quit:           bool,
    sync_requested: bool,
}

poll_frame_events :: proc(
    editor: ^ui.EditorState,
    image_media: ^media.Manager,
) -> FrameEvents {
    result: FrameEvents
    editor.media = image_media
    event: sdl.Event
    for sdl.PollEvent(&event) {
        if event.type == .KEY_DOWN &&
           event.key.key == sdl.K_G &&
           sdl.KMOD_CTRL & event.key.mod != {} &&
           sdl.KMOD_SHIFT & event.key.mod != {} {
            result.sync_requested = true
            continue
        }
        ui.editor_handle_event(editor, &event)
        #partial switch event.type {
        case .MOUSE_WHEEL:
            direction: f32 = event.wheel.direction == .FLIPPED ? -1 : 1
            result.scroll_delta.x += event.wheel.x * direction
            result.scroll_delta.y += event.wheel.y * direction
        case .QUIT:
            result.quit = true
        case .MOUSE_BUTTON_DOWN:
            if event.button.button == sdl.BUTTON_LEFT {
                result.left_pressed = true
            }
        }
    }
    return result
}

update_selected_note :: proc(
    app_state: ^state.AppState,
    documents: ^ui.EditorDocuments,
    editor_state: ^^ui.EditorState,
    empty_editor: ^ui.EditorState,
    loaded_doc: ^string,
    last_saved: ^string,
    face: ^font.Font,
) {
    if app_state.current_doc != loaded_doc^ {
        git_sync.save_focused_note(editor_state^, loaded_doc^, last_saved)
        selected_note := state.current_note(app_state)
        if selected_note != nil {
            editor_state^ = ui.editor_open_note(documents, selected_note, face)
            loaded_doc^ = selected_note.path
            delete(last_saved^)
            last_saved^ = strings.clone(string(selected_note.content))
        } else if app_state.current_doc == "" {
            editor_state^ = empty_editor
            loaded_doc^ = ""
        } else {
            fmt.eprintln("Note not found:", app_state.current_doc)
            app_state.current_doc = loaded_doc^
        }
    }

}


WindowCursors :: struct {
    default_cursor, text_cursor:                    ^sdl.Cursor,
    resize_nwse, resize_nesw, resize_ew, resize_ns: ^sdl.Cursor,
    active:                                         ^sdl.Cursor,
}


FrameSetup :: struct {
    scale_x, scale_y: f32,
    mouse_x, mouse_y: f32,
    mouse_buttons:    sdl.MouseButtonFlags,
}

prepare_frame :: proc(
    window: ^sdl.Window,
    renderer: ^sdl.Renderer,
) -> FrameSetup {
    width, height: i32
    assert(sdl.GetWindowSize(window, &width, &height))
    output_width, output_height: i32
    assert(sdl.GetRenderOutputSize(renderer, &output_width, &output_height))
    scale_x := f32(output_width) / f32(width)
    scale_y := f32(output_height) / f32(height)
    assert(sdl.SetRenderDrawColor(renderer, 0, 0, 0, 0))
    assert(sdl.RenderClear(renderer))

    mouse_x, mouse_y: f32
    mouse_buttons := sdl.GetMouseState(&mouse_x, &mouse_y)
    clay.SetLayoutDimensions({f32(width), f32(height)})
    clay.SetPointerState({mouse_x, mouse_y}, .LEFT in mouse_buttons)
    return {scale_x, scale_y, mouse_x, mouse_y, mouse_buttons}
}

render_app_layout :: proc(
    window: ^sdl.Window,
    renderer: ^sdl.Renderer,
    clay_renderer: ^clay_ui.Clay_Renderer,
    ui_assets: ^assets.Manager,
    app_state: ^state.AppState,
    editor: ^ui.EditorState,
    frame: FrameSetup,
    scroll_delta: clay.Vector2,
    left_pressed: bool,
    delta_seconds: f32,
    settings_state: ui.SettingsDropdownMenuState,
) {
    clay.BeginLayout()
    ui.UILayout(
        ui_assets,
        app_state,
        editor,
        ui.ScrollInput {
            wheel_y = scroll_delta.y,
            mouse = {frame.mouse_x, frame.mouse_y},
            left_down = .LEFT in frame.mouse_buttons,
            left_pressed = left_pressed,
            pointer_in_window = sdl.GetMouseFocus() == window,
        },
        delta_seconds,
        window,
        settings_state,
    )
    commands := clay.EndLayout(delta_seconds)
    clay_ui.render_clay(
        clay_renderer,
        renderer,
        &commands,
        frame.scale_x,
        frame.scale_y,
    )
}

create_app_window :: proc(settings_open: ^bool) -> ^sdl.Window {
    _ = sdl.SetAppMetadata(
        config.WINDOW_TITLE,
        strings.clone_to_cstring(config.VERSION, context.temp_allocator),
        config.APPLICATION_ID,
    )
    if !sdl.Init(sdl.INIT_VIDEO) {
        fmt.eprintln("SDL init failed:", sdl.GetError())
        return nil
    }
    window := sdl.CreateWindow(
        config.WINDOW_TITLE,
        DEFAULT_WIN_W,
        DEFAULT_WIN_H,
        {.RESIZABLE, .HIGH_PIXEL_DENSITY, .BORDERLESS, .TRANSPARENT},
    )
    if window == nil {
        fmt.eprintln("Window creation failed:", sdl.GetError())
        sdl.Quit()
        return nil
    }
    sdl.SetWindowHitTest(window, ui.window_hit_test, settings_open)
    set_window_icon(window)
    return window
}
