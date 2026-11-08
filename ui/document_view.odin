package ui

import clay "shared:clay"

DOCUMENT_SCROLL_ID :: "DocumentViewport"

DocumentView :: proc(ed: ^EditorState, input: ScrollInput = {}, delta_seconds: f32 = 1.0 / 60.0) {
	prepared := editor_prepare_layout(ed)
	bounds := clay.GetElementData(clay.ID(DOCUMENT_SCROLL_ID))
	if bounds.found do ed.scroll.view_height = max(0, bounds.boundingBox.height)
	ed.scroll.content_height = max(
		ed.scroll.view_height,
		prepared.height,
	)

	if ed.reveal_cursor && ed.view_mode == .Source && bounds.found {
		caret_top := f32(EDITOR_PADDING + prepared.cursor_line * EDITOR_LINE_HEIGHT)
		caret_bottom := caret_top + EDITOR_LINE_HEIGHT
		if caret_top < ed.scroll.target + EDITOR_PADDING {
			ed.scroll.target = max(0, caret_top - EDITOR_PADDING)
		}
		if caret_bottom > ed.scroll.target + ed.scroll.view_height - EDITOR_PADDING {
			ed.scroll.target = caret_bottom + EDITOR_PADDING - ed.scroll.view_height
		}
		ed.reveal_cursor = false
	}
	scroll_update(&ed.scroll, input, bounds.boundingBox, delta_seconds)
	ed.first_visible_line = int(max(0, ed.scroll.offset - EDITOR_PADDING) / EDITOR_LINE_HEIGHT)
	if data := clay.GetScrollContainerData(clay.ID(DOCUMENT_SCROLL_ID)); data.found {
		data.scrollPosition.y = -ed.scroll.offset
	}

	if clay.UI(clay.ID(DOCUMENT_SCROLL_ID))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			padding = {0, SCROLLBAR_SPACE, 0, 0},
		},
		clip = {vertical = true, childOffset = {0, -ed.scroll.offset}},
	},
	) {
		if clay.UI(clay.ID("DocumentRow"))(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(ed.scroll.content_height),
				},
				layoutDirection = .LeftToRight,
			},
		},
		) {
			Editor(ed, &prepared)
			Annotations(&prepared, &ed.scroll)
		}
	}
	Scrollbar(clay.ID(DOCUMENT_SCROLL_ID), &ed.scroll)
}
