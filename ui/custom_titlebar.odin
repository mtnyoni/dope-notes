package ui

import theme "../theme"
import clay "shared:clay"
import sdl "vendor:sdl3"

TITLEBAR_HEIGHT :: 32
TITLEBAR_BUTTON_WIDTH :: 48

window_hit_test :: proc "c" (
	window: ^sdl.Window,
	pos: ^sdl.Point,
	data: rawptr,
) -> sdl.HitTestResult {
	if pos.y < TITLEBAR_HEIGHT {
		// Window controls must receive pointer input instead of starting a drag.
		width: i32
		_ = sdl.GetWindowSize(window, &width, nil)
		if pos.x >= width - 3 * TITLEBAR_BUTTON_WIDTH {
			return .NORMAL
		}
		return .DRAGGABLE
	}
	return .NORMAL
}

TitleBar :: proc(window: ^sdl.Window) {
	if clay.UI(clay.ID("TitleBar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TITLEBAR_HEIGHT)},
			layoutDirection = .LeftToRight,
			childAlignment = {y = .Center},
			padding = {16, 0, 0, 0},
		},
		backgroundColor = theme.Light.background,
	},
	) {
		clay.Text("Dope Notes", {fontSize = 14, textColor = theme.Light.text, wrapMode = .None})
		if clay.UI()(
		{layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(1)}}},
		) {}
		TitleBarButton(window, "Minimize", "−", 0)
		TitleBarButton(window, "Maximize", "□", 1)
		TitleBarButton(window, "Close", "×", 2)
	}
}

TitleBarButton :: proc(window: ^sdl.Window, name, label: string, action: int) {
	if clay.UI(clay.ID(name))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(TITLEBAR_BUTTON_WIDTH),
				height = clay.SizingFixed(TITLEBAR_HEIGHT),
			},
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = clay.Hovered() ? (action == 2 ? theme.Cyan_200 : theme.Gray_200) : clay.Color{},
	},
	) {
		if window != nil && clay.Hovered() && clay.GetPointerState().state == .PressedThisFrame {
			switch action {
			case 0:
				_ = sdl.MinimizeWindow(window)
			case 1:
				if .MAXIMIZED in sdl.GetWindowFlags(window) {
					_ = sdl.RestoreWindow(window)
				} else {
					_ = sdl.MaximizeWindow(window)
				}
			case 2:
				event := sdl.Event {
					type = .QUIT,
				}
				_ = sdl.PushEvent(&event)
			}
		}
		clay.Text(label, {fontSize = 20, textColor = theme.Light.text, wrapMode = .None})
	}
}
