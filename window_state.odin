package main

import config "./appconfig"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import sdl "vendor:sdl3"

WindowState :: struct {
    width:     i32,
    height:    i32,
    maximized: bool,
}

window_state_directory :: proc() -> string {
    base := os.get_env("XDG_CONFIG_HOME", context.temp_allocator)
    when ODIN_OS == .Windows {
        base = os.get_env("APPDATA", context.temp_allocator)
    }
    if base == "" {
        home := os.get_env("HOME", context.temp_allocator)
        when ODIN_OS == .Windows {
            home = os.get_env("USERPROFILE", context.temp_allocator)
        }
        if home == "" {return ""}
        when ODIN_OS == .Windows {
            base = fmt.tprintf("%s/AppData/Roaming", home)
        } else {
            base = fmt.tprintf("%s/.config", home)
        }
    }
    return fmt.tprintf("%s/%s", base, config.APPLICATION_ID)
}

load_window_state :: proc() -> WindowState {
    fallback := WindowState {
        width  = DEFAULT_WIN_W,
        height = DEFAULT_WIN_H,
    }
    directory := window_state_directory()
    if directory == "" {return fallback}
    data, ok := os.read_entire_file(
        fmt.tprintf("%s/window.json", directory),
        context.temp_allocator,
    )
    if ok != nil {return fallback}
    saved: WindowState
    if json.unmarshal(data, &saved) != nil {return fallback}
    if saved.width < 320 || saved.height < 240 {return fallback}
    return saved
}

save_window_state :: proc(saved: WindowState) {
    directory := window_state_directory()
    if directory == "" {return}
    if err := os.make_directory_all(directory); err != nil && err != .Exist {return}
    data, err := json.marshal(saved, allocator = context.temp_allocator)
    if err != nil {return}
    if write_err := os.write_entire_file(
        fmt.tprintf("%s/window.json", directory),
        data,
    ); write_err != nil {
        fmt.eprintln("Could not save window state:", write_err)
    }
}

WINDOW_STATE_SETTLE_NS :: 300 * 1_000_000

@(private = "file")
pending_window_state: WindowState
@(private = "file")
pending_since: u64
@(private = "file")
pending_valid: bool

update_saved_window_state :: proc(
    window: ^sdl.Window,
    saved: ^WindowState,
    force := false,
) {
    flags := sdl.GetWindowFlags(window)
    if .MINIMIZED in flags || .FULLSCREEN in flags {return}
    observed := pending_valid ? pending_window_state : saved^
    observed.maximized = .MAXIMIZED in flags
    if !observed.maximized {
        if !sdl.GetWindowSize(window, &observed.width, &observed.height) {
            return
        }
    }
    now := sdl.GetTicksNS()
    if !pending_valid || observed != pending_window_state {
        pending_window_state = observed
        pending_valid = true
        pending_since = now
    }
    if pending_window_state == saved^ {return}
    if force || now - pending_since >= WINDOW_STATE_SETTLE_NS {
        saved^ = pending_window_state
        save_window_state(saved^)
    }
}
