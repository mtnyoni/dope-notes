package ui

import theme "../theme"
import clay "shared:clay"

Annotations :: proc() {
	if clay.UI(clay.ID("Annotations"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(250), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
		},
		border = {color = theme.Light.border, width = {1, 0, 0, 0, 0}},
	},
	) {}
}
