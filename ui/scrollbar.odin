package ui

import theme "../theme"
import "core:math"
import clay "shared:clay"

SCROLLBAR_WIDTH :: 6
SCROLLBAR_SPACE :: 14
SCROLL_WHEEL_DISTANCE :: 72
SCROLL_SMOOTHING_SECONDS :: 0.08

ScrollState :: struct {
	offset:         f32,
	target:         f32,
	view_height:    f32,
	content_height: f32,
	dragging:       bool,
	drag_offset:    f32,
}

ScrollInput :: struct {
	wheel_y:           f32,
	mouse:             clay.Vector2,
	left_down:         bool,
	left_pressed:      bool,
	pointer_in_window: bool,
}

scrollbar_geometry :: proc(scroll: ^ScrollState) -> (height, y: f32) {
	if scroll.view_height <= 0 || scroll.content_height <= scroll.view_height do return 0, 0
	height = min(
		scroll.view_height,
		max(24, scroll.view_height * scroll.view_height / scroll.content_height),
	)
	progress := clamp(scroll.offset / (scroll.content_height - scroll.view_height), 0, 1)
	return height, progress * (scroll.view_height - height)
}

scroll_contains :: proc(bounds: clay.BoundingBox, point: clay.Vector2) -> bool {
	return(
		point.x >= bounds.x &&
		point.x < bounds.x + bounds.width &&
		point.y >= bounds.y &&
		point.y < bounds.y + bounds.height \
	)
}

scroll_update :: proc(
	scroll: ^ScrollState,
	input: ScrollInput,
	viewport: clay.BoundingBox,
	delta_seconds: f32,
) {
	max_offset := max(0, scroll.content_height - scroll.view_height)
	scroll.offset = clamp(scroll.offset, 0, max_offset)
	scroll.target = clamp(scroll.target, 0, max_offset)
	if max_offset <= 0 {
		scroll.dragging = false
		return
	}
	track := clay.BoundingBox {
		viewport.x + viewport.width - SCROLLBAR_WIDTH,
		viewport.y,
		SCROLLBAR_WIDTH,
		scroll.view_height,
	}
	thumb_height, thumb_y := scrollbar_geometry(scroll)
	if input.pointer_in_window && scroll_contains(viewport, input.mouse) && !scroll.dragging {
		scroll.target = clamp(scroll.target - input.wheel_y * SCROLL_WHEEL_DISTANCE, 0, max_offset)
		if input.left_pressed && scroll_contains(track, input.mouse) {
			local_y := input.mouse.y - track.y
			if local_y >= thumb_y && local_y < thumb_y + thumb_height {
				scroll.dragging = true
				scroll.drag_offset = local_y - thumb_y
			} else {
				direction: f32 = local_y < thumb_y ? -1 : 1
				scroll.target = clamp(
					scroll.target + direction * scroll.view_height * 0.9,
					0,
					max_offset,
				)
			}
		}
	}
	if !input.left_down do scroll.dragging = false
	if scroll.dragging {
		travel := scroll.view_height - thumb_height
		if travel > 0 {
			progress := clamp((input.mouse.y - track.y - scroll.drag_offset) / travel, 0, 1)
			scroll.target = progress * max_offset
			scroll.offset = scroll.target
		}
	} else {
		// Exponential easing is independent of frame rate, and preserves
		// fractional trackpad deltas instead of scrolling in whole lines.
		alpha := 1 - math.exp(-max(0, delta_seconds) / SCROLL_SMOOTHING_SECONDS)
		scroll.offset += (scroll.target - scroll.offset) * alpha
		if abs(scroll.target - scroll.offset) < 0.1 do scroll.offset = scroll.target
	}
}

Scrollbar :: proc(scroll_id: clay.ElementId, scroll: ^ScrollState) {
	thumb_h, thumb_y := scrollbar_geometry(scroll)
	if thumb_h <= 0 do return
	if clay.UI(clay.ID("ScrollTrack", scroll_id.id))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(SCROLLBAR_WIDTH),
				height = clay.SizingFixed(scroll.view_height),
			},
		},
		floating = {
			attachTo = .ElementWithId,
			parentId = scroll_id.id,
			attachment = {element = .RightTop, parent = .RightTop},
			pointerCaptureMode = .Passthrough,
			zIndex = 2,
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
				zIndex = 3,
			},
			backgroundColor = scroll.dragging || clay.Hovered() ? theme.Gray_600 : theme.Gray_400,
			cornerRadius = clay.CornerRadiusAll(4),
		},
		) {}
	}
}
