package ui

import assets "../assets"
import theme "../theme"
import clay "shared:clay"

TOOLBAR_HEIGHT :: 54
TOOLBAR_BUTTON_SIZE :: 32

EditorToolBar :: proc(ui_assets: ^assets.Manager, ed: ^EditorState = nil) {
	if clay.UI(clay.ID("EditorToolbar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TOOLBAR_HEIGHT)},
			layoutDirection = .LeftToRight,
			padding = {12, 12, 0, 0},
			childAlignment = {y = .Center},
		},
		border = {color = theme.Light.border, width = {0, 0, 0, 1, 0}},
	},
	) {
		// Equal side groups keep formatting centered independently of the icons.
		if clay.UI(clay.ID("ToolbarHistory"))(
		{
			layout = {
				sizing = {
					width = clay.SizingFixed(ed != nil ? 132 : 64),
					height = clay.SizingFixed(TOOLBAR_BUTTON_SIZE),
				},
				layoutDirection = .LeftToRight,
			},
		},
		) {
			ToolbarIconButton(ui_assets, .Undo)
			ToolbarIconButton(ui_assets, .Redo)
			if ed != nil {
				if clay.UI(clay.ID("EditorViewToggle"))({
					layout = {sizing = {width = clay.SizingFixed(68), height = clay.SizingFixed(TOOLBAR_BUTTON_SIZE)}, childAlignment = {x = .Center, y = .Center}},
					backgroundColor = clay.Hovered() ? theme.Gray_100 : theme.Gray_50,
					cornerRadius = clay.CornerRadiusAll(6),
				}) {
					clay.Text(ed.view_mode == .Preview ? "Edit" : "Preview", {fontSize = 12, textColor = theme.Gray_700, wrapMode = .None})
					if clay.Hovered() && clay.GetPointerState().state == .PressedThisFrame do editor_toggle_preview(ed)
				}
			}
		}
		ToolbarSpacer()
		if clay.UI(clay.ID("ToolbarFormatting"))(
		{
			layout = {
				sizing = {
					width = clay.SizingFit(),
					height = clay.SizingFixed(TOOLBAR_BUTTON_SIZE),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {y = .Center},
				childGap = 2,
			},
		},
		) {
			if clay.UI(clay.ID("ToolbarTextStyle"))(
			{
				layout = {
					sizing = {
						width = clay.SizingFit(),
						height = clay.SizingFixed(TOOLBAR_BUTTON_SIZE),
					},
					layoutDirection = .LeftToRight,
					padding = {8, 8, 0, 0},
					childAlignment = {y = .Center},
					childGap = 10,
				},
				backgroundColor = clay.Hovered() ? theme.Gray_100 : clay.Color{},
				cornerRadius = clay.CornerRadiusAll(6),
			},
			) {
				clay.Text(
					"Normal text",
					{fontId = 0, fontSize = 13, textColor = theme.Gray_700, wrapMode = .None},
				)
				ToolbarImage(ui_assets, .ChevronDown)
			}
			ToolbarSeparator()
			ToolbarIconButton(ui_assets, .LetterB)
			ToolbarIconButton(ui_assets, .Slash)
			ToolbarIconButton(ui_assets, .Underline)
			ToolbarSeparator()
			ToolbarIconButton(ui_assets, .TextAlignStart, dropdown = true)
			ToolbarIconButton(ui_assets, .List)
			ToolbarIconButton(ui_assets, .ListOrdered)
			ToolbarSeparator()
			ToolbarIconButton(ui_assets, .Link)
		}
		ToolbarSpacer()
		if clay.UI(clay.ID("ToolbarMenu"))(
		{
			layout = {
				sizing = {
					width = clay.SizingFixed(ed != nil ? 132 : 64),
					height = clay.SizingFixed(TOOLBAR_BUTTON_SIZE),
				},
				childAlignment = {x = .Right, y = .Center},
			},
		},
		) {
			ToolbarIconButton(ui_assets, .EllipsisVertical, filled = true)
		}
	}
}

ToolbarIconButton :: proc(
	ui_assets: ^assets.Manager,
	icon: assets.Icon,
	dropdown := false,
	filled := false,
) {
	width: f32 = TOOLBAR_BUTTON_SIZE
	if dropdown do width = 48
	if clay.UI(clay.ID("ToolbarButton", u32(icon)))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(width),
				height = clay.SizingFixed(TOOLBAR_BUTTON_SIZE),
			},
			layoutDirection = .LeftToRight,
			childAlignment = {x = .Center, y = .Center},
			childGap = 4,
		},
		backgroundColor = clay.Hovered() ? theme.Gray_100 : (filled ? theme.Gray_50 : clay.Color{}),
		cornerRadius = clay.CornerRadiusAll(6),
	},
	) {
		ToolbarImage(ui_assets, icon)
		if dropdown do ToolbarImage(ui_assets, .ChevronDown)
	}
}


ToolbarImage :: proc(ui_assets: ^assets.Manager, icon: assets.Icon) {
	texture := assets.get(ui_assets, icon)
	if texture == nil do return

	if clay.UI()(
	{
		layout = {sizing = {width = clay.SizingFixed(16), height = clay.SizingFixed(16)}},
		image = {imageData = rawptr(texture)},
	},
	) {}
}

ToolbarSeparator :: proc() {
	if clay.UI()(
	{
		layout = {
			sizing = {width = clay.SizingFixed(13), height = clay.SizingFixed(22)},
			childAlignment = {x = .Center},
		},
	},
	) {
		if clay.UI()(
		{
			layout = {sizing = {width = clay.SizingFixed(1), height = clay.SizingGrow()}},
			backgroundColor = theme.Light.border,
		},
		) {}
	}
}

ToolbarSpacer :: proc() {
	if clay.UI()(
	{layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(1)}}},
	) {}
}
