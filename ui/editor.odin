package ui

import clay "shared:clay"

Editor :: proc() {
	clay.UI(clay.ID("Sidebar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
		},
		backgroundColor = {233, 22, 23, 1},
	},
	){}
}
