package ui

import assets "../assets"
import markdown "../markdown"
import state "../state"
import theme "../theme"
import clay "shared:clay"

SIDEBAR_ITEM_TITLE_FONT_SIZE :: 13
SIDEBAR_ITEM_DESCRIPTION_FONT_SIZE :: 12

Sidebar :: proc(ui_assets: ^assets.Manager, app_state: ^state.AppState) {
	notebook := state.current_notebook(app_state)
	notebook_name := "No notebooks"
	note_files: []markdown.NoteFile
	if notebook != nil {
		notebook_name = notebook.name
		note_files = notebook.notes[:]
	}
	clicked := clay.GetPointerState().state == .PressedThisFrame
	chevron_up_down_icon := assets.get(ui_assets, .ChevronsUpDown)
	search_icon := assets.get(ui_assets, .Search)
	square_pen_icon := assets.get(ui_assets, .SquarePen)

	if clay.UI(clay.ID("Sidebar"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(250), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
			padding = clay.Padding{top = 0, right = 4, left = 4, bottom = 4},
		},
		backgroundColor = theme.Light.background,
	},
	) {
		if clay.UI(clay.ID("SidebarPanel"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .TopToBottom,
				padding = clay.PaddingAll(8),
				childAlignment = clay.ChildAlignment{y = clay.LayoutAlignmentY.Center},
			},
			backgroundColor = theme.Light.surface,
			border = clay.BorderElementConfig {
				width = clay.BorderWidth{left = 1, top = 1, right = 1, bottom = 1},
				color = theme.Light.border,
			},
			cornerRadius = clay.CornerRadiusAll(4),
		},
		) {
			if clay.UI()(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(32)},
					padding = clay.PaddingAll(8),
				},
				backgroundColor = clay.Hovered() ? theme.Gray_100 : theme.White,
				cornerRadius = clay.CornerRadiusAll(4),
			},
			) {
				clay.Text(
					notebook_name,
					{
						fontId = 0,
						fontSize = SIDEBAR_ITEM_TITLE_FONT_SIZE + 1,
						textColor = theme.Light.text,
						wrapMode = .None,
					},
				)
				if clay.UI()({layout = {sizing = {width = clay.SizingGrow()}}}) {}
				if chevron_up_down_icon != nil {
					if clay.UI()(
					{
						layout = {
							sizing = {width = clay.SizingFixed(16), height = clay.SizingFixed(16)},
						},
						image = {imageData = rawptr(chevron_up_down_icon)},
					},
					) {}
				}
			}

			if clay.UI(clay.ID("NewNoteButton"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(32)},
					padding = clay.PaddingAll(8),
					layoutDirection = .LeftToRight,
					childAlignment = clay.ChildAlignment{y = .Center},
					childGap = 4,
				},
				backgroundColor = clay.Hovered() ? theme.Gray_100 : theme.White,
				cornerRadius = clay.CornerRadiusAll(8),
			},
			) {
				if clicked && clay.Hovered() do app_state.new_note_requested = true
				if square_pen_icon != nil {
					// Align the icon with the visible letters within the font's line box.
					if clay.UI()({
						layout = {
							sizing = {width = clay.SizingFixed(12), height = clay.SizingFixed(16)},
							padding = clay.Padding{left = 0, right = 0, top = 2, bottom = 0},
							childAlignment = clay.ChildAlignment{y = .Center},
						},
					}) {
						if clay.UI()({
							layout = {
								sizing = {width = clay.SizingFixed(12), height = clay.SizingFixed(12)},
							},
							image = {imageData = rawptr(square_pen_icon)},
						}) {}
					}
				}
				clay.Text(
					"New Note",
					{
						fontId = 0,
						fontSize = SIDEBAR_ITEM_TITLE_FONT_SIZE,
						textColor = theme.Light.text,
						wrapMode = .None,
					},
				)
			}

			if clay.UI()(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(32)},
					padding = clay.PaddingAll(8),
					layoutDirection = .LeftToRight,
					childAlignment = clay.ChildAlignment{y = .Center},
					childGap = 4,
				},
				backgroundColor = clay.Hovered() ? theme.Gray_100 : theme.White,
				cornerRadius = clay.CornerRadiusAll(8),
			},
			) {
				if search_icon != nil {
					// Align the icon with the visible letters within the font's line box.
					if clay.UI()({
						layout = {
							sizing = {width = clay.SizingFixed(12), height = clay.SizingFixed(16)},
							padding = clay.Padding{left = 0, right = 0, top = 2, bottom = 0},
							childAlignment = clay.ChildAlignment{y = .Center},
						},
					}) {
						if clay.UI()({
							layout = {
								sizing = {width = clay.SizingFixed(12), height = clay.SizingFixed(12)},
							},
							image = {imageData = rawptr(search_icon)},
						}) {}
					}
				}
				clay.Text(
					"Search",
					{
						fontId = 0,
						fontSize = SIDEBAR_ITEM_TITLE_FONT_SIZE,
						textColor = theme.Light.text,
						wrapMode = .None,
					},
				)
			}

			if clay.UI(clay.ID("SidebarNotesScroll"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .TopToBottom,
					childGap = 2,
					padding = clay.Padding{top = 8},
				},
				clip = {vertical = true, childOffset = clay.GetScrollOffset()},
			},
			) {
				if len(note_files) == 0 {
					clay.Text(
						"No notes yet",
						{
							fontSize = SIDEBAR_ITEM_DESCRIPTION_FONT_SIZE,
							textColor = theme.Light.text_secondary,
						},
					)
				}
				for article, index in note_files {
					if clay.UI(clay.ID("ArticleCard", u32(index)))(
					{
						layout = {
							sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
							layoutDirection = .TopToBottom,
							padding = clay.PaddingAll(12),
							childGap = 4,
						},
						backgroundColor = app_state.current_doc == article.path ? theme.Cyan_200 : (clay.Hovered() ? theme.Cyan_100 : theme.White),
						cornerRadius = clay.CornerRadiusAll(8),
					},
					) {
						if clicked && clay.Hovered() {
							app_state.current_doc = article.path
						}

						if clay.UI(clay.ID("ArticleTitle", u32(index)))(
						{
							layout = {
								sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
							},
							clip = {horizontal = true},
						},
						) {clay.Text(article.title, {fontId = 0, fontSize = SIDEBAR_ITEM_TITLE_FONT_SIZE, textColor = theme.Light.text, wrapMode = .None})}

						if clay.UI(clay.ID("ArticleDescription", u32(index)))(
						{
							layout = {
								sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
							},
							clip = {horizontal = true},
						},
						) {
							clay.Text(
								article.description,
								{
									fontId = 0,
									fontSize = SIDEBAR_ITEM_DESCRIPTION_FONT_SIZE,
									textColor = theme.Light.text_secondary,
									wrapMode = .None,
								},
							)
						}
					}
				}
			}
		}
	}
}
