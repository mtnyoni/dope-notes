package markdown

import "core:strings"
import theme "../theme"
import commonmark "vendor:commonmark"

SourceLine :: struct { start, end: int }

source_lines :: proc(text: string) -> [dynamic]SourceLine {
	lines := make([dynamic]SourceLine, context.temp_allocator)
	start := 0
	for i in 0 ..< len(text) {
		if text[i] == '\n' {
			append(&lines, SourceLine{start, i})
			start = i + 1
		}
	}
	append(&lines, SourceLine{start, len(text)})
	return lines
}

// Use a full-document AST so fenced code, list nesting, and inline emphasis
// retain their context when one source line is exposed for editing.
prepare_live_markdown_layout :: proc(root: ^commonmark.Node, options: RenderOptions, source: string, active_line: int) -> DocumentLayout {
	base := prepare_markdown_layout(root, options)
	source_rows := source_lines(source)
	live := DocumentLayout{blocks = make([dynamic]RenderBlock, context.temp_allocator)}
	seen := make([]bool, len(base.blocks), context.temp_allocator)
	block_index := 0
	for row, index in source_rows {
		line_number := index + 1
		for block_index < len(base.blocks) && base.blocks[block_index].source_end_line < line_number do block_index += 1
		original: ^RenderBlock
		if block_index < len(base.blocks) && base.blocks[block_index].source_line <= line_number do original = &base.blocks[block_index]
		if index == active_line {
			block := raw_source_block(source, row, line_number, options)
			if original != nil {
				block.node = original.node
				seen[block_index] = true
			}
			if original != nil && line_number == original.source_end_line do block.spacing = original.spacing
			block.height += block.spacing
			append(&live.blocks, block)
			live.height += block.height
			continue
		}
		if original == nil do continue
		block := original^
		block.source_line = line_number
		block.source_end_line = line_number
		block.spacing = line_number == original.source_end_line ? original.spacing : 0
		if seen[block_index] {
			block.marker = ""
			if len(original.marker) > 0 do block.indent += 24
		}
		if block.rule {
			seen[block_index] = true
			append(&live.blocks, block)
			live.height += block.height
			continue
		}
		spans := make([dynamic]TextSpan, context.temp_allocator)
		if original.code {
			literal := strings.trim_right(string(commonmark.node_get_literal(original.node)), "\r\n")
			literal_rows := strings.split_lines(literal, context.temp_allocator)
			first_row := source_rows[original.source_line - 1]
			fence_column := clamp(int(commonmark.node_get_start_column(original.node)) - 1, 0, first_row.end - first_row.start)
			first_text := strings.trim_space(source[first_row.start + fence_column:first_row.end])
			fenced := commonmark.node_get_type(original.node) == .Code_Block && (strings.has_prefix(first_text, "```") || strings.has_prefix(first_text, "~~~"))
			literal_index := line_number - original.source_line - (fenced ? 1 : 0)
			if literal_index < 0 || literal_index >= len(literal_rows) do continue
			text := literal_rows[literal_index]
			column := max(0, strings.index(source[row.start:row.end], text)) + 1
			append(&spans, TextSpan{text = text, color = theme.Gray_800, source_line = line_number, source_column = column})
			block.top_padding = literal_index == 0 ? 10 : 0
			block.bottom_padding = literal_index == len(literal_rows) - 1 ? 10 : 0
			// A hidden closing fence must not swallow the block's final spacing.
			if literal_index == len(literal_rows) - 1 do block.spacing = 12
		} else {
			all := make([dynamic]TextSpan, context.temp_allocator)
			collect_inline(original.node, &all, commonmark.node_get_type(original.node) == .Heading ? 1 : 0, original.quote ? theme.Gray_600 : theme.Light.text)
			for span in all {
				if span.source_line == line_number do append(&spans, span)
			}
			if len(spans) == 0 do continue
		}
		width := max(1, options.width - block.indent - block.padding * 2 - (block.quote ? 10 : 0) - (len(block.marker) > 0 ? 24 : 0))
		block.lines = wrap_inline(spans[:], width, block.font_size, options, block.code)
		block.height = f32(len(block.lines)) * block.line_height + block.top_padding + block.bottom_padding + block.spacing
		seen[block_index] = true
		append(&live.blocks, block)
		live.height += block.height
	}
	// Syntax-only lines (setext underlines and closing fences) can be hidden.
	// Keep each original block's bottom spacing on its last visible line.
	for original in base.blocks {
		for i := len(live.blocks) - 1; i >= 0; i -= 1 {
			if live.blocks[i].node == original.node {
				delta := original.spacing - live.blocks[i].spacing
				live.blocks[i].spacing = original.spacing
				live.blocks[i].height += delta
				live.height += delta
				break
			}
		}
	}
	return live
}

raw_source_block :: proc(source: string, row: SourceLine, line_number: int, options: RenderOptions) -> RenderBlock {
	block := RenderBlock{font_size = 15, line_height = 24, active = true, source_line = line_number, source_end_line = line_number, lines = make([dynamic]RenderLine, context.temp_allocator)}
	start, at := row.start, row.start
	last_space := -1
	for at < row.end {
		next := at + 1
		for next < row.end && (source[next] & 0xC0) == 0x80 do next += 1
		if source[at] == ' ' || source[at] == '\t' do last_space = at
		span := TextSpan{text = source[start:next], color = theme.Light.text}
		if at > start && span_width(span, 15, options) > options.width {
			break_at := at
			if last_space > start do break_at = last_space + 1
			append_raw_line(&block, source, start, break_at, row.start, line_number)
			start = break_at
			last_space = -1
		}
		at = next
	}
	append_raw_line(&block, source, start, row.end, row.start, line_number)
	block.height = f32(len(block.lines)) * block.line_height
	return block
}

append_raw_line :: proc(block: ^RenderBlock, text: string, start, end, physical_start, line_number: int) {
	spans := make([dynamic]TextSpan, context.temp_allocator)
	append(&spans, TextSpan{text = text[start:end], color = theme.Light.text, source_line = line_number, source_column = start - physical_start + 1})
	append(&block.lines, RenderLine{spans = spans, source_start = start, source_end = end})
}
