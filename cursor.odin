package main

import sdl "vendor:sdl3"
import clay "shared:clay"
import ui "ui"

create_window_cursors :: proc() -> WindowCursors {
    default_cursor := sdl.GetDefaultCursor()
    return WindowCursors {
        default_cursor = default_cursor,
        text_cursor = sdl.CreateSystemCursor(.TEXT),
        resize_nwse = sdl.CreateSystemCursor(.NWSE_RESIZE),
        resize_nesw = sdl.CreateSystemCursor(.NESW_RESIZE),
        resize_ew = sdl.CreateSystemCursor(.EW_RESIZE),
        resize_ns = sdl.CreateSystemCursor(.NS_RESIZE),
        active = default_cursor,
    }
}

destroy_window_cursors :: proc(cursors: ^WindowCursors) {
    if cursors.default_cursor != nil {
        _ = sdl.SetCursor(cursors.default_cursor)
    }
    if cursors.text_cursor != nil {sdl.DestroyCursor(cursors.text_cursor)}
    if cursors.resize_nwse != nil {sdl.DestroyCursor(cursors.resize_nwse)}
    if cursors.resize_nesw != nil {sdl.DestroyCursor(cursors.resize_nesw)}
    if cursors.resize_ew != nil {sdl.DestroyCursor(cursors.resize_ew)}
    if cursors.resize_ns != nil {sdl.DestroyCursor(cursors.resize_ns)}
    cursors^ = {}
}

update_window_cursor :: proc(
    window: ^sdl.Window,
    cursors: ^WindowCursors,
    mouse_x, mouse_y: f32,
    settings_open: ^bool,
) {
    if cursors.default_cursor != nil {
        cursor := cursors.default_cursor
        if sdl.GetMouseFocus() == window {
            point := sdl.Point{i32(mouse_x), i32(mouse_y)}
            hit := ui.window_hit_test(window, &point, settings_open)
            #partial switch hit {
            case .RESIZE_TOPLEFT, .RESIZE_BOTTOMRIGHT:
                cursor = cursors.resize_nwse
            case .RESIZE_TOPRIGHT, .RESIZE_BOTTOMLEFT:
                cursor = cursors.resize_nesw
            case .RESIZE_LEFT, .RESIZE_RIGHT:
                cursor = cursors.resize_ew
            case .RESIZE_TOP, .RESIZE_BOTTOM:
                cursor = cursors.resize_ns
            case:
                if clay.PointerOver(
                    clay.ID(ui.EDITOR_ID),
                ) {cursor = cursors.text_cursor}
            }
        }
        if cursor == nil {cursor = cursors.default_cursor}
        if cursor != cursors.active &&
           sdl.SetCursor(cursor) {cursors.active = cursor}
    }
}
