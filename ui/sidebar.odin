package ui

import clay "shared:clay"

Sidebar :: proc() {
	if clay.UI(clay.ID("Sidebar"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(250), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
		},
		backgroundColor = {23, 22, 12, 255},
	},
	) {}
}
