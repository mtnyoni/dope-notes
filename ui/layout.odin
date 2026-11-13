package ui

import assets "../assets"
import state "../state"
import theme "../theme"
import clay "shared:clay"
import sdl "vendor:sdl3"

UILayout :: proc(
	ui_assets: ^assets.Manager,
	app_state: ^state.AppState,
	ed: ^EditorState,
	scroll_input: ScrollInput = {},
	delta_seconds: f32 = 1.0 / 60.0,
	window: ^sdl.Window = nil,
) {
	maximized := window != nil && .MAXIMIZED in sdl.GetWindowFlags(window)
	if clay.UI(clay.ID("Root"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(maximized ? 0 : 4),
		},
		backgroundColor = theme.Light.background,
		cornerRadius = clay.CornerRadiusAll(maximized ? 0 : 12),
		border = clay.BorderElementConfig {
			width = clay.BorderWidth{left = 1, top = 1, right = 1, bottom = 1},
			color = theme.Light.border,
		},
	},
	) {
		TitleBar(window, ui_assets)
		if clay.UI(clay.ID("MainArea"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .LeftToRight,
			},
		},
		) {
			Sidebar(ui_assets, app_state)
			if clay.UI(clay.ID("Content"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .TopToBottom,
					padding = clay.Padding{left = 4, right = 4, top = 0, bottom = 4},
				},
			},
			) {
				if clay.UI(clay.ID("ContentPanel"))(
				{
					layout = {
						sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
						layoutDirection = .TopToBottom,
					},
					cornerRadius = clay.CornerRadiusAll(4),
					backgroundColor = theme.Light.surface,
					border = clay.BorderElementConfig {
						width = clay.BorderWidth{left = 1, top = 1, right = 1, bottom = 1},
						color = theme.Light.border,
					},
				},
				) {
					EditorToolBar(ui_assets)

					if clay.UI()(
					{
						layout = {
							sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
							layoutDirection = .LeftToRight,
							padding = clay.PaddingAll(8),
						},
					},
					) {
						DocumentView(ed, scroll_input, delta_seconds)
					}
				}
			}
		}
	}
}
