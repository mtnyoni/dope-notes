package ui

import theme "../theme"
import clay "shared:clay"

Scrollbar :: proc(scroll_id: clay.ElementId) {
	data := clay.GetScrollContainerData(scroll_id)
	if !data.found do return

	view_h := data.scrollContainerDimensions.height
	content_h := data.contentDimensions.height
	if view_h <= 0 || content_h <= view_h do return // nothing to scroll

	thumb_h := min(view_h, max(view_h * (view_h / content_h), 24))
	progress := clamp(-data.scrollPosition.y / (content_h - view_h), 0, 1)
	thumb_y := progress * (view_h - thumb_h)

	// track, pinned to the right edge of the scroll container
	if clay.UI(clay.ID("ScrollTrack", scroll_id.id))(
	{
		layout = {sizing = {width = clay.SizingFixed(6), height = clay.SizingFixed(view_h)}},
		floating = {
			attachTo = .ElementWithId,
			parentId = scroll_id.id,
			attachment = {element = .RightTop, parent = .RightTop},
			pointerCaptureMode = .Passthrough,
		},
		backgroundColor = theme.Light.border,
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		if clay.UI(clay.ID("ScrollThumb", scroll_id.id))(
		{
			layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(thumb_h)}},
			floating = {
				attachTo = .Parent,
				offset = {0, thumb_y},
				attachment = {element = .LeftTop, parent = .LeftTop},
				pointerCaptureMode = .Passthrough,
			},
			backgroundColor = clay.Hovered() ? theme.Gray_600 : theme.Gray_400,
			cornerRadius = clay.CornerRadiusAll(4),
		},
		) {}
	}
}
