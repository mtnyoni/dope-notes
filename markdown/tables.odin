package markdown

import "core:strings"
import theme "../theme"
import clay "shared:clay"
import commonmark "vendor:commonmark"

TableCell :: struct {
	lines: [dynamic]RenderLine,
	width: f32,
	alignment: clay.LayoutAlignmentX,
	source_start, source_end: int,
}

// Detect tables only in paragraph source, never inside fenced code blocks.
prepare_table_rows :: proc(source: string, rows: []SourceLine, base: DocumentLayout, options: RenderOptions) -> map[int]RenderBlock {
	result := make(map[int]RenderBlock, context.temp_allocator)
	for original in base.blocks {
		if original.node == nil || original.code || original.quote || len(original.marker) > 0 || commonmark.node_get_type(original.node) != .Paragraph do continue
		first := original.source_line - 1
		last := min(original.source_end_line, len(rows))
		if first + 1 >= last do continue
		header := table_cells(source, rows[first])
		delimiters := table_cells(source, rows[first+1])
		if len(header) == 0 || len(header) != len(delimiters) do continue
		alignments := make([]clay.LayoutAlignmentX, len(header), context.temp_allocator)
		valid := true
		for cell, i in delimiters {
			value := strings.trim_space(source[cell.start:cell.end])
			left := strings.has_prefix(value, ":")
			right := strings.has_suffix(value, ":")
			value = strings.trim(value, ":")
			if len(value) < 3 { valid = false; break }
			for byte in transmute([]u8)value { if byte != '-' do valid = false }
			alignments[i] = left && right ? .Center : (right ? .Right : .Left)
		}
		if !valid do continue
		for index in first..<last {
			if index == first+1 {
				result[index] = RenderBlock{table = true, source_line = index+1, source_end_line = index+1}
				continue
			}
			slices := table_cells(source, rows[index])
			if len(slices) == 0 do break
			block := RenderBlock{table = true, table_header = index == first, font_size = 15, line_height = 24, source_line = index+1, source_end_line = index+1}
			block.table_cells = make([dynamic]TableCell, context.temp_allocator)
			width := max(1, options.width / f32(len(header)))
			for column in 0..<len(header) {
				range := SourceLine{rows[index].end, rows[index].end}
				if column < len(slices) do range = slices[column]
				spans := make([dynamic]TextSpan, context.temp_allocator)
				root := commonmark.parse_document_from_string(source[range.start:range.end], {})
				collect_inline(root, &spans, block.table_header ? 1 : 0, theme.Light.text)
				for &span in spans {
					span.text = strings.clone(span.text, context.temp_allocator)
					span.source_line = index+1
					span.source_column += range.start - rows[index].start
				}
				commonmark.node_free(root)
				lines := wrap_inline(spans[:], max(1, width-16), 15, options, false)
				if len(spans) == 0 {
					append(&lines[0].spans, TextSpan{text = "", source_line = index+1, source_column = range.start-rows[index].start+1, color = theme.Light.text})
				}
				for &line, i in lines {
					line.source_base = rows[index].start
					line.source_start = range.start
					if i > 0 && len(line.spans) > 0 do line.source_start = rows[index].start+line.spans[0].source_column-1
					line.source_end = range.end
					if i > 0 do lines[i-1].source_end = line.source_start
				}
				append(&block.table_cells, TableCell{lines = lines, width = width, alignment = alignments[column], source_start = range.start, source_end = range.end})
				block.height = max(block.height, f32(len(lines))*24+16)
			}
			result[index] = block
		}
	}
	return result
}

// Keep source byte ranges for editing, including escaped pipes inside cells.
table_cells :: proc(source: string, row: SourceLine) -> [dynamic]SourceLine {
	cells := make([dynamic]SourceLine, context.temp_allocator)
	start, end := row.start, row.end
	for start < end && (source[start] == ' ' || source[start] == '\t') do start += 1
	for end > start && (source[end-1] == ' ' || source[end-1] == '\t') do end -= 1
	if start == end do return cells
	pipes := 0
	cell_start := start
	for at := start; at < end; at += 1 {
		if source[at] == '\\' { at += 1; continue }
		if source[at] != '|' do continue
		pipes += 1
		if at != start do append(&cells, SourceLine{cell_start, at})
		cell_start = at+1
	}
	if pipes == 0 do return cells
	if cell_start < end do append(&cells, SourceLine{cell_start, end})
	for &cell in cells {
		for cell.start < cell.end && (source[cell.start] == ' ' || source[cell.start] == '\t') do cell.start += 1
		for cell.end > cell.start && (source[cell.end-1] == ' ' || source[cell.end-1] == '\t') do cell.end -= 1
	}
	return cells
}

render_table_row :: proc(block: RenderBlock, options: RenderOptions) {
	caret_drawn := false
	for cell in block.table_cells {
		if clay.UI()({
			layout = {
				sizing = {width = clay.SizingFixed(cell.width), height = clay.SizingGrow()},
				layoutDirection = .TopToBottom,
				padding = clay.Padding{left = 8, right = 8, top = 8, bottom = 8},
			},
			backgroundColor = block.table_header ? theme.Gray_100 : theme.Light.surface,
			clip = {horizontal = true},
			border = {color = theme.Light.border, width = clay.BorderAll(1)},
		}) {
			for line, index in cell.lines {
				if clay.UI()({layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(block.line_height)},
					layoutDirection = .LeftToRight,
					childAlignment = {x = cell.alignment, y = .Center},
				}}) {
					for span in line.spans {
						if clay.UI()({layout = {sizing = {width = clay.SizingFit(), height = clay.SizingFit()}}, backgroundColor = span.selected ? theme.Light.selection : clay.Color{}}) {
							clay.Text(span.text, {fontSize = block.font_size, fontId = span.style, textColor = span.color, wrapMode = .None})
						}
					}
					last := index == len(cell.lines)-1
					if !caret_drawn && options.show_caret && options.cursor >= line.source_start && (options.cursor < line.source_end || (last && options.cursor == line.source_end)) {
						caret_drawn = true
						x, y, height := caret_geometry(block, line, options)
						x += table_line_offset(cell, line, block.font_size, options)
						if clay.UI(clay.ID("Caret"))({
							layout = {sizing = {width = clay.SizingFixed(2), height = clay.SizingFixed(height)}},
							floating = {attachTo = .Parent, offset = {x, y}, zIndex = 1, pointerCaptureMode = .Passthrough},
							backgroundColor = theme.Light.text,
						}) {}
					}
				}
			}
		}
	}
}

// Return the inset used by centered or right-aligned cell text.
table_line_offset :: proc(cell: TableCell, line: RenderLine, size: u16, options: RenderOptions) -> f32 {
	width: f32
	for span in line.spans do width += span_width(span, size, options)
	remaining := max(0, cell.width-16-width)
	if cell.alignment == .Center do return remaining/2
	if cell.alignment == .Right do return remaining
	return 0
}

table_pick_cursor :: proc(block: RenderBlock, x, y: f32, options: RenderOptions) -> int {
	left: f32
	for cell, column in block.table_cells {
		if x <= left+cell.width || column == len(block.table_cells)-1 {
			index := clamp(int((y-8)/block.line_height), 0, len(cell.lines)-1)
			line := cell.lines[index]
			remaining := x-left-8-table_line_offset(cell, line, block.font_size, options)
			position := line.source_start
			for span in line.spans {
				start := line.source_base+span.source_column-1
				for at := 0; at < len(span.text); {
					next := at+1
					for next < len(span.text) && (span.text[next]&0xC0) == 0x80 do next += 1
					part := span
					part.text = span.text[at:next]
					width := span_width(part, block.font_size, options)
					if remaining < width/2 do return clamp(start+at, cell.source_start, cell.source_end)
					remaining -= width
					position = start+next
					at = next
				}
			}
			return clamp(position, cell.source_start, cell.source_end)
		}
		left += cell.width
	}
	return 0
}
