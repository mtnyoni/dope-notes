package ui

import theme "../theme"
import clay "shared:clay"

Sidebar :: proc() {
	if clay.UI(clay.ID("Sidebar"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(250), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
			padding = {8, 8, 8, 8},
		},
		backgroundColor = theme.Light.background,
	},
	) {
		if clay.UI()(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .LeftToRight,
				padding = {8, 8, 8, 8},
			},
			backgroundColor = theme.Light.surface,
			cornerRadius = {16, 16, 16, 16},
		},
		) {

		}
	}
}
