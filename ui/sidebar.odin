package ui

import notes "../notes"
import state "../state"
import theme "../theme"
import clay "shared:clay"

SIDEBAR_ITEM_TITLE_FONT_SIZE :: 13
SIDEBAR_ITEM_DESCRIPTION_FONT_SIZE :: 12

Sidebar :: proc(app_state: ^state.AppState) {
	clicked := clay.GetPointerState().state == .PressedThisFrame

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
		if clay.UI(clay.ID("SidebarPanel"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .TopToBottom,
				padding = {8, 8, 8, 8},
			},
			backgroundColor = theme.Light.surface,
			cornerRadius = {16, 16, 16, 16},
		},
		) {
			if clay.UI()(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(32)},
					padding = {8, 8, 8, 8},
				},
			},
			) {
				clay.Text(
					"Business Planning",
					{
						fontId = 0,
						fontSize = EDITOR_FONT_SIZE,
						textColor = theme.Light.text,
						wrapMode = .None,
					},
				)
			}

			if clay.UI()(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(32)},
					padding = {8, 8, 8, 8},
				},
			},
			) {
				clay.Text(
					"New Note",
					{
						fontId = 0,
						fontSize = EDITOR_FONT_SIZE,
						textColor = theme.Light.text,
						wrapMode = .None,
					},
				)
			}

			if clay.UI()(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(32)},
					padding = {8, 8, 8, 8},
				},
			},
			) {
				clay.Text(
					"Search",
					{
						fontId = 0,
						fontSize = EDITOR_FONT_SIZE,
						textColor = theme.Light.text,
						wrapMode = .None,
					},
				)
			}

			if clay.UI()(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .TopToBottom,
					childGap = 2,
				},
			},
			) {
				for article, index in notes.notes_list {
					if clay.UI(clay.ID("ArticleCard", u32(index)))(
					{
						layout = {
							sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
							layoutDirection = .TopToBottom,
							padding = {12, 12, 12, 12},
							childGap = 4,
						},
						backgroundColor = app_state.current_doc == article.slug ? theme.Cyan_200 : (clay.Hovered() ? theme.Cyan_100 : theme.White),
						cornerRadius = {8, 8, 8, 8},
					},
					) {
						if clicked && clay.Hovered() {
							app_state.current_doc = article.slug
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
