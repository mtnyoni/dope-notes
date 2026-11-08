package ui

import clay "shared:clay"

Editor :: proc() {
	if clay.UI(clay.ID("Editor"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
		},
		backgroundColor = {233, 22, 23, 255},
	},
	) {}
}
