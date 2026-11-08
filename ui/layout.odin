package ui

import assets "../assets"
import state "../state"
import theme "../theme"
import clay "shared:clay"

UILayout :: proc(
	ui_assets: ^assets.Manager,
	app_state: ^state.AppState,
	ed: ^EditorState,
	scroll_input: ScrollInput = {},
	delta_seconds: f32 = 1.0 / 60.0,
) {
	if clay.UI(clay.ID("Root"))(
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
				padding = {0, 8, 8, 8},
			},
			cornerRadius = clay.CornerRadiusAll(16),
		},
		) {
			if clay.UI(clay.ID("ContentPanel"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .TopToBottom,
				},
				cornerRadius = clay.CornerRadiusAll(16),
				backgroundColor = theme.Light.surface,
			},
			) {
				EditorToolBar(ui_assets, ed)

				if clay.UI()(
				{
					layout = {
						sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
						layoutDirection = .LeftToRight,
						padding = {8, 8, 8, 8},
					},
					cornerRadius = clay.CornerRadiusAll(16),
				},
				) {
					DocumentView(ed, scroll_input, delta_seconds)
				}
			}
		}
	}
}
