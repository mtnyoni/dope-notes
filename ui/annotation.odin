package ui

import theme "../theme"
import clay "shared:clay"

ANNOTATION_MAP_WIDTH :: 40
ANNOTATION_MAP_PADDING :: 4

Annotations :: proc(prepared: ^EditorTextLayout) {
	if clay.UI(clay.ID("Annotations"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(400), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
		},
	},
	) {
		if clay.UI(clay.ID("AnnotationsView"))(
		{layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}}},
		) {}

		if clay.UI(clay.ID("AnnotationsMap"))(
		{
			layout = {
				sizing = {
					width = clay.SizingFixed(ANNOTATION_MAP_WIDTH),
					height = clay.SizingGrow(),
				},
				layoutDirection = .TopToBottom,
				childGap = 2,
				padding = {
					ANNOTATION_MAP_PADDING,
					ANNOTATION_MAP_PADDING,
					EDITOR_PADDING,
					EDITOR_PADDING,
				},
			},
		},
		) {
			max_line := get_max_line(prepared.lines)
			for line, index in prepared.lines {
				perc := calc_perc((line.end - line.start), max_line)
				if clay.UI(clay.ID("AnnotationMapLine", u32(index)))(
				{
					layout = {
						sizing = {
							width = clay.SizingFixed(
								perc * (ANNOTATION_MAP_WIDTH - ANNOTATION_MAP_PADDING * 2),
							),
							height = clay.SizingFixed(2),
						},
					},
					backgroundColor = theme.Gray_400,
					cornerRadius = clay.CornerRadiusAll(998),
				},
				) {}
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
