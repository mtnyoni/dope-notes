package ui

import clay "shared:clay"

Annotations :: proc() {
	clay.UI(clay.ID("Sidebar"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(250), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
		},
		backgroundColor = {233, 22, 23, 1},
	},
	){}
}
