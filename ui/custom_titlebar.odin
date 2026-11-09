package ui

import assets "../assets"
import theme "../theme"
import clay "shared:clay"
import sdl "vendor:sdl3"

TITLEBAR_HEIGHT :: 40
TITLEBAR_BUTTON_WIDTH :: 32
TITLEBAR_BUTTON_GAP :: 1
TITLEBAR_RESIZE_EDGE :: 6
TITLEBAR_RESIZE_CORNER :: 12

window_hit_test :: proc "c" (
	window: ^sdl.Window,
	pos: ^sdl.Point,
	data: rawptr,
) -> sdl.HitTestResult {
	return titlebar_hit_test(window, pos)
}

titlebar_hit_test :: proc "c" (window: ^sdl.Window, pos: ^sdl.Point) -> sdl.HitTestResult {
	width, height: i32
	if !sdl.GetWindowSize(window, &width, &height) do return .NORMAL
	if .MAXIMIZED in sdl.GetWindowFlags(window) {
		if pos.y < TITLEBAR_HEIGHT && pos.x < width - (3 * TITLEBAR_BUTTON_WIDTH + 2 * TITLEBAR_BUTTON_GAP) do return .DRAGGABLE
		return .NORMAL
	}
	left := pos.x < TITLEBAR_RESIZE_EDGE
	right := pos.x >= width - TITLEBAR_RESIZE_EDGE
	top := pos.y < TITLEBAR_RESIZE_EDGE
	bottom := pos.y >= height - TITLEBAR_RESIZE_EDGE
	if pos.y < TITLEBAR_RESIZE_CORNER {
		if pos.x < TITLEBAR_RESIZE_CORNER do return .RESIZE_TOPLEFT
		if pos.x >= width - TITLEBAR_RESIZE_CORNER do return .RESIZE_TOPRIGHT
	}
	if pos.y >= height - TITLEBAR_RESIZE_CORNER {
		if pos.x < TITLEBAR_RESIZE_CORNER do return .RESIZE_BOTTOMLEFT
		if pos.x >= width - TITLEBAR_RESIZE_CORNER do return .RESIZE_BOTTOMRIGHT
	}
	if top do return .RESIZE_TOP
	if bottom do return .RESIZE_BOTTOM
	if left do return .RESIZE_LEFT
	if right do return .RESIZE_RIGHT
	if pos.y < TITLEBAR_HEIGHT && pos.x < width - (3 * TITLEBAR_BUTTON_WIDTH + 2 * TITLEBAR_BUTTON_GAP) do return .DRAGGABLE
	return .NORMAL
}

TitleBar :: proc(window: ^sdl.Window, ui_assets: ^assets.Manager) {
	if clay.UI(clay.ID("TitleBar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TITLEBAR_HEIGHT)},
			layoutDirection = .LeftToRight,
			childAlignment = {y = .Center},
			padding = {8, 0, 0, 0},
		},
		border = clay.BorderElementConfig {
			width = clay.BorderWidth{bottom = 1},
			color = theme.Light.border,
		},
	},
	) {
		if ui_assets != nil && ui_assets.app_icon != nil {
			if clay.UI(clay.ID("TitleBarIcon"))(
			{
				layout = {sizing = {width = clay.SizingFixed(16), height = clay.SizingFixed(16)}},
				image = {imageData = rawptr(ui_assets.app_icon)},
			},
			) {}
		}
		if clay.UI(clay.ID("TitleBarTitle"))(
		{
			layout = {
				sizing = {width = clay.SizingFit(), height = clay.SizingFit()},
				padding = {8, 0, 0, 0},
			},
		},
		) {
			clay.Text(
				"Dope notes",
				{fontSize = 13, textColor = theme.Light.text, wrapMode = .None},
			)
		}

		if clay.UI()(
		{layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(1)}}},
		) {}

		if clay.UI()(
		{
			layout = clay.LayoutConfig {
				sizing = {width = clay.SizingFit(), height = clay.SizingFixed(TITLEBAR_HEIGHT)},
				layoutDirection = .LeftToRight,
				childAlignment = {y = .Center},
				childGap = TITLEBAR_BUTTON_GAP,
			},
		},
		) {
			TitleBarButton(window, ui_assets, "Minimize", 0)
			TitleBarButton(window, ui_assets, "Maximize", 1)
			TitleBarButton(window, ui_assets, "Close", 2)
		}
	}
}

TitleBarButton :: proc(
	window: ^sdl.Window,
	ui_assets: ^assets.Manager,
	name: string,
	action: int,
) {
	if clay.UI(clay.ID(name))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(TITLEBAR_BUTTON_WIDTH),
				height = clay.SizingFixed(TITLEBAR_HEIGHT),
			},
			childAlignment = {x = .Center, y = .Center},
		},
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
		icon: assets.Icon = .Square

		switch action {
		case 0:
			icon = .Square
		case 1:
			icon =
				window != nil && .MAXIMIZED in sdl.GetWindowFlags(window) ? .SquaresUnite : .Square
		case 2:
			icon = .X
		}

		hovered := clay.Hovered()
		if clay.UI(clay.ID("TitleBarButtonFace", u32(action)))(
		{
			layout = {
				sizing = {width = clay.SizingFixed(28), height = clay.SizingFixed(28)},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = hovered ? theme.Gray_200 : clay.Color{},
			cornerRadius = clay.CornerRadiusAll(14),
		},
		) {
			if action == 0 {
				clay.Text("−", {fontSize = 16, textColor = theme.Light.text, wrapMode = .None})
			} else if texture := assets.get(ui_assets, icon); texture != nil {
				if clay.UI()(
				{
					layout = {
						sizing = {width = clay.SizingFixed(12), height = clay.SizingFixed(12)},
					},
					image = {imageData = rawptr(texture)},
				},
				) {}
			}
		}
	}
}
