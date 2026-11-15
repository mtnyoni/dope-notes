package ui

import assets "../assets"
import config "../appconfig"
import "core:fmt"
import "core:strings"
import theme "../theme"
import clay "shared:clay"
import sdl "vendor:sdl3"

TITLEBAR_HEIGHT :: 32
TITLEBAR_BUTTON_WIDTH :: 28
TITLEBAR_BUTTON_GAP :: 1
TITLEBAR_ABOUT_WIDTH :: 28
TITLEBAR_CONTROLS_WIDTH :: TITLEBAR_ABOUT_WIDTH + 3 * TITLEBAR_BUTTON_WIDTH + 3 * TITLEBAR_BUTTON_GAP
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
	controls_left := width - TITLEBAR_CONTROLS_WIDTH - 8 - (.MAXIMIZED in sdl.GetWindowFlags(window) ? 0 : 4)
	if .MAXIMIZED in sdl.GetWindowFlags(window) {
		if pos.y < TITLEBAR_HEIGHT && pos.x < controls_left do return .DRAGGABLE
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
	if pos.y < TITLEBAR_HEIGHT && pos.x < controls_left do return .DRAGGABLE

	return .NORMAL
}

TitleBar :: proc(window: ^sdl.Window, ui_assets: ^assets.Manager, settings_open: ^bool, menu_sync_pending: ^bool) {
	if clay.UI(clay.ID("TitleBar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TITLEBAR_HEIGHT)},
			layoutDirection = .LeftToRight,
			childAlignment = {y = .Center},
			padding = clay.Padding{left = 8, right = 8, top = 0, bottom = 0},
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
			TitleBarButton(window, ui_assets, "Settings", 3, settings_open)
			TitleBarButton(window, ui_assets, "Minimize", 0)
			TitleBarButton(window, ui_assets, "Maximize", 1)
			TitleBarButton(window, ui_assets, "Close", 2)
		}
		if settings_open != nil && settings_open^ {
			SettingsMenu(window, settings_open, menu_sync_pending)
		}
	}
}

TitleBarButton :: proc(
	window: ^sdl.Window,
	ui_assets: ^assets.Manager,
	name: string,
	action: int,
	settings_open: ^bool = nil,
) {
	if clay.UI(clay.ID(name))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(action == 3 ? TITLEBAR_ABOUT_WIDTH : TITLEBAR_BUTTON_WIDTH),
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
			case 3:
				if settings_open != nil do settings_open^ = !settings_open^
			}
		}
		icon: assets.Icon = .Square

		switch action {
		case 0:
			icon = .Minus
		case 1:
			icon =
				window != nil && .MAXIMIZED in sdl.GetWindowFlags(window) ? .SquaresUnite : .Square
		case 2:
			icon = .X
		case 3:
			icon = .Settings
		}

		hovered := clay.Hovered()
		if clay.UI(clay.ID("TitleBarButtonFace", u32(action)))(
		{
			layout = {
				sizing = {width = clay.SizingFixed(action == 3 ? TITLEBAR_ABOUT_WIDTH : 28), height = clay.SizingFixed(28)},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = hovered ? theme.Gray_200 : clay.Color{},
			cornerRadius = clay.CornerRadiusAll(action == 3 ? 6 : 14),
		},
		) {
			if texture := assets.get(ui_assets, icon); texture != nil {
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

SettingsMenu :: proc(window: ^sdl.Window, settings_open: ^bool, menu_sync_pending: ^bool) {
	if clay.UI(clay.ID("SettingsMenu"))({
		layout = {
			sizing = {width = clay.SizingFixed(112), height = clay.SizingFit()},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(4),
		},
		floating = {
			attachTo = .ElementWithId,
			parentId = clay.ID("Settings").id,
			attachment = {element = .LeftTop, parent = .LeftBottom},
			zIndex = 10,
		},
		backgroundColor = theme.White,
		cornerRadius = clay.CornerRadiusAll(6),
		border = clay.BorderElementConfig {width = clay.BorderWidth{left = 1, top = 1, right = 1, bottom = 1}, color = theme.Light.border},
	}) {
		items := [2]string{"Sync", "About"}
		for label, index in items {
			hovered := false
			if clay.UI(clay.ID("SettingsMenuItem", u32(index)))({
				layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(28)}, childAlignment = {y = .Center}, padding = clay.Padding{left = 8}},
				backgroundColor = theme.White,
				cornerRadius = clay.CornerRadiusAll(4),
			}) {
				hovered = clay.Hovered()
				clay.Text(label, {fontSize = 12, textColor = theme.Light.text, wrapMode = .None})
			}
			if hovered && clay.GetPointerState().state == .PressedThisFrame {
				settings_open^ = false
				if index == 0 {
					if menu_sync_pending != nil do menu_sync_pending^ = true
				} else if window != nil {
					message := fmt.tprintf("Dope Notes\nVersion %s", config.DISPLAY_VERSION)
					_ = sdl.ShowSimpleMessageBox({.INFORMATION}, "About Dope Notes", strings.clone_to_cstring(message, context.temp_allocator), window)
				}
			}
		}
	}
}
