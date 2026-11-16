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
	menu_open := data != nil && (cast(^bool)data)^

	if .MAXIMIZED in sdl.GetWindowFlags(window) {
		if !menu_open && pos.y < TITLEBAR_HEIGHT && pos.x < controls_left do return .DRAGGABLE
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
	if !menu_open && pos.y < TITLEBAR_HEIGHT && pos.x < controls_left do return .DRAGGABLE

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
			TitleBarButton(ui_assets, {
				name = "Settings",
				corner_radius = 6,
				icon = .Settings,
				on_click = proc(data: rawptr) {
					if data == nil do return
					open := cast(^bool)data
					open^ = !open^
				},
				on_click_data = settings_state.open,
			})

			TitleBarButton(ui_assets, {
				name = "Minimize",
				corner_radius = 14,
				icon = .Minus,
				on_click = proc(data: rawptr) {
					if data != nil do _ = sdl.MinimizeWindow(cast(^sdl.Window)data)
				},
				on_click_data = window,
			})

			maximize_icon: assets.Icon =
				window != nil && .MAXIMIZED in sdl.GetWindowFlags(window) ? .SquaresUnite : .Square
			TitleBarButton(ui_assets, {
				name = "Maximize",
				corner_radius = 14,
				icon = maximize_icon,
				on_click = proc(data: rawptr) {
					window := cast(^sdl.Window)data
					if window == nil do return
					if .MAXIMIZED in sdl.GetWindowFlags(window) {
						_ = sdl.RestoreWindow(window)
					} else {
						_ = sdl.MaximizeWindow(window)
					}
				},
				on_click_data = window,
			})

			TitleBarButton(ui_assets, {
				name = "Close",
				corner_radius = 14,
				icon = .X,
				on_click = proc(data: rawptr) {
					event := sdl.Event {
						type = .QUIT,
					}
					_ = sdl.PushEvent(&event)
				},
			})
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

TitleButtonCallback :: proc(data: rawptr)
TitleBarButtonConfig :: struct {
	name:          string,
	icon:          assets.Icon,
	on_click:      TitleButtonCallback,
	on_click_data: rawptr,
	corner_radius: f32,
}

TitleBarButton :: proc(ui_assets: ^assets.Manager, config: TitleBarButtonConfig) {
	if clay.UI(clay.ID(config.name))(
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
		face_id := clay.ID("TitleBarButtonFace", clay.ID(config.name).id)
		hovered := clay.Hovered() || clay.PointerOver(face_id)
		clicked := hovered && clay.GetPointerState().state == .PressedThisFrame
		if clicked && config.on_click != nil do config.on_click(config.on_click_data)

		if clay.UI(face_id)(
		{
			layout = clay.LayoutConfig {
				sizing = clay.Sizing {
					width = clay.SizingFixed(TITLEBAR_BUTTON_WIDTH),
					height = clay.SizingFixed(28),
				},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = hovered ? theme.Gray_200 : clay.Color{},
			cornerRadius = clay.CornerRadiusAll(config.corner_radius),
		},
		) {
			if texture := assets.get(ui_assets, config.icon); texture != nil {
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
	about: ^AboutDialogState,
	github_setup: ^GithubSetupState,
	toast: ^ToastState,
	sync_busy: bool,
}

SettingsDropdownMenu :: proc(window: ^sdl.Window, menu_state: SettingsDropdownMenuState) {
	animation_progress :=
		menu_state.animation_progress != nil ? menu_state.animation_progress^ : 1.0
	animation_easing := animation_progress * animation_progress * (3 - 2 * animation_progress)
	dropdown_width: f32 = 260
	button_bounds := clay.GetElementData(clay.ID("Settings")).boundingBox
	right_inset := f32(TITLEBAR_HORIZONTAL_PADDING)
	if window != nil && .MAXIMIZED not_in sdl.GetWindowFlags(window) {
		right_inset += WINDOW_OUTER_PADDING
	}

	if clay.UI(clay.ID("SettingsMenu"))(
	{
		layout = clay.LayoutConfig {
			sizing = clay.Sizing {
				width = clay.SizingFixed(28 + (dropdown_width - 28) * animation_easing),
				height = clay.SizingFixed(92 * animation_easing),
			},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(4),
		},
		floating = clay.FloatingElementConfig {
			attachTo = .Root,
			attachment = clay.FloatingAttachPoints{element = .RightTop, parent = .RightTop},
			offset = clay.Vector2{-right_inset, button_bounds.y + button_bounds.height},
			zIndex = 10,
		},
		clip = clay.ClipElementConfig{horizontal = true, vertical = true},
		backgroundColor = theme.White,
		cornerRadius = clay.CornerRadiusAll(6),
		border = clay.BorderElementConfig {
			width = clay.BorderWidth{left = 1, top = 1, right = 1, bottom = 1},
			color = theme.Light.border,
		},
	},
	) {
		sync_state := menu_state
		DropdownMenuItem({
			name = "SettingsSync",
			label = "Sync",
			on_click = proc(data: rawptr) {
				state := cast(^SettingsDropdownMenuState)data
				if state.open != nil do state.open^ = false
				if state.sync_pending != nil do state.sync_pending^ = true
			},
			on_click_data = &sync_state,
		})

        DropdownMenuItem({
            name = "SettingsResetGithub",
            label = "Reset GitHub connection",
            on_click = proc(data: rawptr) {
                state := cast(^SettingsDropdownMenuState)data
                if state.open != nil {state.open^ = false}
                if state.github_setup != nil {state.github_setup.reset_requested = true}
            },
            on_click_data = &sync_state,
        })

		DropdownMenuItem({
			name = "SettingsAbout",
			label = "About",
			on_click = proc(data: rawptr) {
				state := cast(^SettingsDropdownMenuState)data
                if state.open != nil do state.open^ = false
                if state.about != nil {
                    state.about.open = true
                    state.about.just_opened = true
                }
			},
			on_click_data = &sync_state,
		})
	}

	if menu_state.open != nil &&
	   menu_state.open^ &&
	   clay.GetPointerState().state == .PressedThisFrame &&
	   !clay.PointerOver(clay.ID("SettingsMenu")) &&
	   !clay.PointerOver(clay.ID("Settings")) {
		menu_state.open^ = false
	}
}

DropdownMenuItemConfig :: struct {
	name:          string,
	label:         string,
	on_click:      proc(data: rawptr),
	on_click_data: rawptr,
}

DropdownMenuItem :: proc(item: DropdownMenuItemConfig) {
	id := clay.ID(item.name)
	hovered := clay.PointerOver(id)
	if clay.UI(id)(
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
		clay.Text(
			item.label,
			clay.TextElementConfig{fontSize = 12, textColor = theme.Light.text, wrapMode = .None},
		)
		if hovered && clay.GetPointerState().state == .PressedThisFrame && item.on_click != nil {
			item.on_click(item.on_click_data)
		}
	}
}
