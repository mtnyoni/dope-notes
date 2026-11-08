package ui

import clay "shared:clay"

Scrollbar :: proc(scroll_id: clay.ElementId) {
	data := clay.GetScrollContainerData(scroll_id)
	if !data.found do return

	view_h := data.scrollContainerDimensions.height
	content_h := data.contentDimensions.height
	if content_h <= view_h do return // nothing to scroll

	thumb_h := max(view_h * (view_h / content_h), 24)
	progress := -data.scrollPosition.y / (content_h - view_h) // position is negative
	thumb_y := progress * (view_h - thumb_h)

	// track, pinned to the right edge of the scroll container
	if clay.UI(clay.ID("ScrollTrack"))(
	{
		layout = {sizing = {width = clay.SizingFixed(8), height = clay.SizingFixed(view_h)}},
		floating = {
			attachTo = .ElementWithId,
			parentId = scroll_id.id,
			attachment = {element = .RightTop, parent = .RightTop},
		},
		backgroundColor = {0, 0, 0, 30},
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		if clay.UI(clay.ID("ScrollThumb"))(
		{
			layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(thumb_h)}},
			floating = {
				attachTo = .Parent,
				offset = {0, thumb_y},
				attachment = {element = .LeftTop, parent = .LeftTop},
			},
			backgroundColor = clay.Hovered() ? {0, 0, 0, 140} : {0, 0, 0, 90},
			cornerRadius = clay.CornerRadiusAll(4),
		},
		) {}
	}
}
