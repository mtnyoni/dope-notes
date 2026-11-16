package ui

import config "../appconfig"
import assets "../assets"
import theme "../theme"
import "core:fmt"
import "core:strings"
import clay "shared:clay"
import sdl "vendor:sdl3"

TITLEBAR_HEIGHT :: 32
TITLEBAR_BUTTON_WIDTH :: 28
TITLEBAR_BUTTON_GAP :: 1
TITLEBAR_HORIZONTAL_PADDING :: 8
WINDOW_OUTER_PADDING :: 4
TITLEBAR_BUTTON_COUNT :: 4
// hit test uses the controls width to keep the buttons clickable.
TITLEBAR_CONTROLS_WIDTH ::
	TITLEBAR_BUTTON_COUNT * TITLEBAR_BUTTON_WIDTH +
	(TITLEBAR_BUTTON_COUNT - 1) * TITLEBAR_BUTTON_GAP
TITLEBAR_RESIZE_EDGE :: 6
TITLEBAR_RESIZE_CORNER :: 12

window_hit_test :: proc "c" (
	window: ^sdl.Window,
	pos: ^sdl.Point,
	data: rawptr,
) -> sdl.HitTestResult {
	width, height: i32
	if !sdl.GetWindowSize(window, &width, &height) do return .NORMAL
	controls_left :=
		width -
		TITLEBAR_CONTROLS_WIDTH -
		TITLEBAR_HORIZONTAL_PADDING -
		(.MAXIMIZED in sdl.GetWindowFlags(window) ? 0 : WINDOW_OUTER_PADDING)

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

TitleBar :: proc(
	window: ^sdl.Window,
	ui_assets: ^assets.Manager,
	delta_seconds: f32,
	settings_state: SettingsDropdownMenuState,
) {
	if clay.UI(clay.ID("TitleBar"))(
	{
		layout = clay.LayoutConfig {
			sizing = clay.Sizing {
				width = clay.SizingGrow(),
				height = clay.SizingFixed(TITLEBAR_HEIGHT),
			},
			layoutDirection = .LeftToRight,
			childAlignment = clay.ChildAlignment{y = .Center},
			padding = clay.Padding {
				left = TITLEBAR_HORIZONTAL_PADDING,
				right = TITLEBAR_HORIZONTAL_PADDING,
			},
		},
	},
	) {
		if ui_assets != nil && ui_assets.app_icon != nil {
			if clay.UI(clay.ID("TitleBarIcon"))(
			{
				layout = clay.LayoutConfig {
					sizing = {width = clay.SizingFixed(16), height = clay.SizingFixed(16)},
				},
				image = clay.ImageElementConfig{imageData = rawptr(ui_assets.app_icon)},
			},
			) {}
		}

		if clay.UI(clay.ID("TitleBarTitle"))(
		{
			layout = clay.LayoutConfig {
				sizing = clay.Sizing{width = clay.SizingFit(), height = clay.SizingFit()},
				padding = clay.Padding{left = 8},
			},
		},
		) {
			clay.Text(
				"Dope notes",
				clay.TextElementConfig {
					fontSize = 13,
					textColor = theme.Light.text,
					wrapMode = .None,
				},
			)
		}

		if clay.UI()(
		{
			layout = clay.LayoutConfig {
				sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingFixed(1)},
			},
		},
		) {}

		if clay.UI()(
		{
			layout = clay.LayoutConfig {
				sizing = clay.Sizing {
					width = clay.SizingFit(),
					height = clay.SizingFixed(TITLEBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = clay.ChildAlignment{y = .Center},
				childGap = TITLEBAR_BUTTON_GAP,
			},
		},
		) {
			TitleBarButton(window, ui_assets, "Settings", .TOGGLE_SETTINGS, settings_state.open)
			TitleBarButton(window, ui_assets, "Minimize", .MINIMIZE)
			TitleBarButton(window, ui_assets, "Maximize", .MAXIMIZE)
			TitleBarButton(window, ui_assets, "Close", .CLOSE)
		}

		if settings_state.animation_progress != nil {
			settings_state.animation_progress^ = clamp(
				settings_state.animation_progress^ +
				(settings_state.open != nil && settings_state.open^ ? 1.0 : -1.0) *
					delta_seconds *
					9,
				0,
				1,
			)
		}

		if settings_state.open != nil &&
		   (settings_state.open^ ||
				   settings_state.animation_progress != nil &&
					   settings_state.animation_progress^ > 0) {

			SettingsDropdownMenu(window, settings_state)
		}
	}
}

TitleButtonAction :: enum {
	MINIMIZE        = 0,
	MAXIMIZE        = 1,
	CLOSE           = 2,
	TOGGLE_SETTINGS = 3,
}

TitleBarButton :: proc(
	window: ^sdl.Window,
	ui_assets: ^assets.Manager,
	name: string,
	action: TitleButtonAction,
	settings_open: ^bool = nil,
) {
	if clay.UI(clay.ID(name))(
	{
		layout = clay.LayoutConfig {
			sizing = clay.Sizing {
				width = clay.SizingFixed(TITLEBAR_BUTTON_WIDTH),
				height = clay.SizingFixed(TITLEBAR_HEIGHT),
			},
			childAlignment = clay.ChildAlignment{x = .Center, y = .Center},
		},
	},
	) {
		icon: assets.Icon = .Square
		hovered := clay.Hovered()
		clicked := window != nil && hovered && clay.GetPointerState().state == .PressedThisFrame

		switch action {
		case .MINIMIZE:
			icon = .Minus
			if clicked do _ = sdl.MinimizeWindow(window)

		case .MAXIMIZE:
			icon =
				window != nil && .MAXIMIZED in sdl.GetWindowFlags(window) ? .SquaresUnite : .Square
			if clicked {
				if .MAXIMIZED in sdl.GetWindowFlags(window) {
					_ = sdl.RestoreWindow(window)
				} else {
					_ = sdl.MaximizeWindow(window)
				}
			}

		case .CLOSE:
			icon = .X
			if clicked {
				event := sdl.Event {
					type = .QUIT,
				}
				_ = sdl.PushEvent(&event)
			}

		case .TOGGLE_SETTINGS:
			icon = .Settings
			if clicked && settings_open != nil do settings_open^ = !settings_open^
		}

		if clay.UI(clay.ID("TitleBarButtonFace", u32(action)))(
		{
			layout = clay.LayoutConfig {
				sizing = clay.Sizing {
					width = clay.SizingFixed(TITLEBAR_BUTTON_WIDTH),
					height = clay.SizingFixed(28),
				},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = hovered ? theme.Gray_200 : clay.Color{},
			cornerRadius = clay.CornerRadiusAll(action == .TOGGLE_SETTINGS ? 6 : 14),
		},
		) {
			if texture := assets.get(ui_assets, icon); texture != nil {
				if clay.UI()(
				{
					layout = clay.LayoutConfig {
						sizing = clay.Sizing {
							width = clay.SizingFixed(12),
							height = clay.SizingFixed(12),
						},
					},
					image = clay.ImageElementConfig{imageData = rawptr(texture)},
				},
				) {}
			}
		}
	}
}

SettingsDropdownMenuState :: struct {
	open:               ^bool,
	sync_pending:       ^bool,
	animation_progress: ^f32,
}

SettingsDropdownMenu :: proc(window: ^sdl.Window, menu_state: SettingsDropdownMenuState) {
	menu_items := [2]string{"Sync", "About"}
	animation_progress :=
		menu_state.animation_progress != nil ? menu_state.animation_progress^ : 1.0
	animation_easing := animation_progress * animation_progress * (3 - 2 * animation_progress)

	if clay.UI(clay.ID("SettingsMenu"))(
	{
		layout = clay.LayoutConfig {
			sizing = clay.Sizing {
				width = clay.SizingFixed(28 + 84 * animation_easing),
				height = clay.SizingFixed(64 * animation_easing),
			},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(4),
		},
		floating = {
			attachTo = .ElementWithId,
			parentId = clay.ID("Settings").id,
			attachment = {element = .LeftTop, parent = .LeftBottom},
			zIndex = 10,
		},
		clip = {horizontal = true, vertical = true},
		backgroundColor = theme.White,
		cornerRadius = clay.CornerRadiusAll(6),
		border = clay.BorderElementConfig {
			width = clay.BorderWidth{left = 1, top = 1, right = 1, bottom = 1},
			color = theme.Light.border,
		},
	},
	) {
		for label, index in menu_items {
			hovered := false
			if clay.UI(clay.ID("SettingsMenuItem", u32(index)))(
			{
				layout = clay.LayoutConfig {
					sizing = clay.Sizing{width = clay.SizingGrow(), height = clay.SizingFixed(28)},
					childAlignment = clay.ChildAlignment{y = .Center},
					padding = clay.Padding{left = 8},
				},
				backgroundColor = hovered ? theme.Gray_100 : theme.White,
				cornerRadius = clay.CornerRadiusAll(4),
			},
			) {
				hovered = clay.Hovered()
				clay.Text(
					label,
					clay.TextElementConfig {
						fontSize = 12,
						textColor = theme.Light.text,
						wrapMode = .None,
					},
				)
			}

			if hovered && clay.GetPointerState().state == .PressedThisFrame {
				menu_state.open^ = false

				if index == 0 {
					if menu_state.sync_pending != nil do menu_state.sync_pending^ = true
				} else if window != nil {
					message := fmt.tprintf("Dope Notes\nVersion %s", config.DISPLAY_VERSION)
					_ = sdl.ShowSimpleMessageBox(
						{.INFORMATION},
						"About Dope Notes",
						strings.clone_to_cstring(message, context.temp_allocator),
						window,
					)
				}
			}
		}
	}

	if menu_state.open != nil &&
	   menu_state.open^ &&
	   clay.GetPointerState().state == .PressedThisFrame &&
	   !clay.PointerOver(clay.ID("SettingsMenu")) &&
	   !clay.PointerOver(clay.ID("Settings")) {
		menu_state.open^ = false
	}
}
