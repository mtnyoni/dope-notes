package ui

import theme "../theme"
import clay "shared:clay"

ANNOTATION_MAP_WIDTH :: 40
ANNOTATION_MAP_PADDING :: 4

Annotations :: proc(prepared: ^EditorTextLayout, scroll: ^ScrollState) {
	if clay.UI(clay.ID("Annotations"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(400), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
			padding = {0, ANNOTATION_MAP_WIDTH, 0, 0},
		},
	},
	) {
		if clay.UI(clay.ID("AnnotationsView"))(
		{layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}}},
		) {}

		pitch, indicator_height, indicator_y := annotation_map_geometry(len(prepared.lines), scroll)
		if clay.UI(clay.ID("AnnotationsMap"))(
		{
			layout = {
				sizing = {
					width = clay.SizingFixed(ANNOTATION_MAP_WIDTH),
					height = clay.SizingFixed(scroll.view_height),
				},
				layoutDirection = .TopToBottom,
				padding = {
					ANNOTATION_MAP_PADDING,
					ANNOTATION_MAP_PADDING,
					EDITOR_PADDING,
					EDITOR_PADDING,
				},
			},
			floating = {
				attachTo = .ElementWithId,
				parentId = clay.ID(DOCUMENT_SCROLL_ID).id,
				attachment = {element = .RightTop, parent = .RightTop},
				offset = {-SCROLLBAR_SPACE, 0},
				pointerCaptureMode = .Passthrough,
				zIndex = 1,
			},
			clip = {horizontal = true, vertical = true},
		},
		) {
			max_line := get_max_line(prepared.lines)
			for line, index in prepared.lines {
				perc := calc_perc(line.end - line.start, max_line)
				if clay.UI(clay.ID("AnnotationMapRow", u32(index)))({
					layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(pitch)}},
				}) {
					if clay.UI(clay.ID("AnnotationMapLine", u32(index)))({
						layout = {
							sizing = {
								width = clay.SizingFixed(perc * (ANNOTATION_MAP_WIDTH - ANNOTATION_MAP_PADDING * 2)),
								height = clay.SizingFixed(pitch * 0.5),
							},
						},
						backgroundColor = theme.Gray_400,
						cornerRadius = clay.CornerRadiusAll(1),
					}) {}
				}
			}
			if indicator_height > 0 {
				tint := theme.Cyan_500
				tint[3] = 40
				outline := theme.Cyan_700
				outline[3] = 120
				if clay.UI(clay.ID("AnnotationMapIndicator"))({
					layout = {
						sizing = {
							width = clay.SizingFixed(ANNOTATION_MAP_WIDTH - ANNOTATION_MAP_PADDING * 2),
							height = clay.SizingFixed(indicator_height),
						},
					},
					floating = {
						attachTo = .Parent,
						offset = {ANNOTATION_MAP_PADDING, EDITOR_PADDING + indicator_y},
						zIndex = 2,
						pointerCaptureMode = .Passthrough,
						clipTo = .AttachedParent,
					},
					backgroundColor = tint,
					border = {color = outline, width = {1, 1, 1, 1, 0}},
					cornerRadius = clay.CornerRadiusAll(3),
				}) {}
			}
		}
	}
}

get_max_line :: proc(lines: [dynamic]EditorLine) -> int {
	max_length := 0
	for line in lines {
		max_length = max(max_length, line.end - line.start)
	}
	return max_length
}

calc_perc :: proc(line_length: int, max_length: int) -> f32 {
	if max_length <= 0 do return 0
	return clamp(f32(line_length) / f32(max_length), 0, 1)
}

// Compress long maps to the viewport while retaining the 4-pixel line pitch
// for shorter documents. ScrollState is current even when switching notes.
annotation_map_geometry :: proc(line_count: int, scroll: ^ScrollState) -> (pitch, indicator_height, indicator_y: f32) {
	if line_count <= 0 || scroll.content_height <= 0 do return
	available := max(0, scroll.view_height - EDITOR_PADDING * 2)
	pitch = min(4, available / f32(line_count))
	map_height := f32(line_count) * pitch
	scale := map_height / scroll.content_height
	indicator_height = clamp(scroll.view_height * scale, 0, map_height)
	indicator_y = clamp(scroll.offset * scale, 0, max(0, map_height - indicator_height))
	return
}
