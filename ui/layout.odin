package ui

import theme "../theme"
import clay "shared:clay"

UILayout :: proc(ed: ^EditorState) {
	if clay.UI(clay.ID("Root"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
		},
	},
	) {
		Sidebar()
		if clay.UI(clay.ID("Content"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .TopToBottom,
				padding = {0, 8, 8, 8},
			},
			cornerRadius = {16, 16, 16, 16},
		},
		) {
			if clay.UI(clay.ID("ContentPanel"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .TopToBottom,
				},
				cornerRadius = {16, 16, 16, 16},
				backgroundColor = theme.Light.surface,
			},
			) {
				EditorToolBar()

				if clay.UI()(
				{
					layout = {
						sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
						layoutDirection = .LeftToRight,
						padding = {8, 8, 8, 8},
					},
					cornerRadius = {16, 16, 16, 16},
				},
				) {
					Editor(ed)
					Annotations()
				}
			}
		}
	}
}

EditorToolBar :: proc() {
	if clay.UI()(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(40)},
			layoutDirection = .LeftToRight,
			padding = {0, 8, 8, 8},
		},
		border = {color = theme.Light.border, width = {0, 0, 0, 1, 0}},
	},
	) {

	}
}
