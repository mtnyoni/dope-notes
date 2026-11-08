package ui

import clay "shared:clay"

UILayout :: proc() {
	clay.UI_AutoId()(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
		},
	},
	){Sidebar(), clay.UI_AutoId()({}){Editor(), Annotations()}}
}
