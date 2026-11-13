package markdown

import theme "../theme"
import "core:fmt"
import "core:strings"
import clay "shared:clay"
import commonmark "vendor:commonmark"

MeasureText :: #type proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	user_data: rawptr,
) -> clay.Dimensions

RenderOptions :: struct {
	width:                          f32,
	measure:                        MeasureText,
	user_data:                      rawptr,
	show_caret:                     bool,
	cursor:                         int,
	selection_start, selection_end: int,
}

TextSpan :: struct {
	text:          string,
	style:         u16, // FreeType style bits: 1 = bold, 2 = italic.
	color:         clay.Color,
	code:          bool,
	selected:      bool,
	source_line:   int,
	source_column: int,
}

RenderLine :: struct {
	source_base: int,
	spans:                    [dynamic]TextSpan,
	source_start, source_end: int,
}
RenderBlock :: struct {
	math: bool,
	formula: MathBox,
	table, table_header: bool,
	table_cells: [dynamic]TableCell,
	lines:                        [dynamic]RenderLine,
	font_size:                    u16,
	line_height:                  f32,
	indent:                       f32,
	marker:                       string,
	code, quote, rule:            bool,
	padding:                      f32,
	height:                       f32,
	spacing:                      f32,
	top_padding, bottom_padding:  f32,
	source_line, source_end_line: int,
	active:                       bool,
	node:                         ^commonmark.Node,
}
DocumentLayout :: struct {
	blocks: [dynamic]RenderBlock,
	height: f32,
}

// Layout is computed before Clay draws so the shared document scroller knows
// the formatted height, rather than the number of source Markdown lines.
prepare_markdown_layout :: proc(root: ^commonmark.Node, options: RenderOptions) -> DocumentLayout {
	layout := DocumentLayout {
		blocks = make([dynamic]RenderBlock, context.temp_allocator),
	}
	if root != nil do append_markdown_blocks(root, &layout, options, 0, "", false)
	return layout
}

render_markdown_ast_to_clay :: proc(
	root: ^commonmark.Node,
	options: RenderOptions,
	prepared: ^DocumentLayout = nil,
) {
	if root == nil do return

	prepared := prepared
	local: DocumentLayout
	if prepared == nil {
		local = prepare_markdown_layout(root, options)
		prepared = &local
	}

	for block, index in prepared.blocks {
		left_padding := u16(block.indent)
		bottom_padding := u16(block.spacing)
		if clay.UI(clay.ID("MarkdownBlock", u32(index)))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(block.height)},
				layoutDirection = .LeftToRight,
				padding = clay.Padding {
					left = left_padding,
					right = 0,
					top = 0,
					bottom = bottom_padding,
				},
			},
			cornerRadius = clay.CornerRadiusAll(4),
		},
		) {
			if block.math {
				render_math(block.formula)
				continue
			}
			if block.table {
				render_table_row(block)
				continue
			}

			if block.rule {
				if clay.UI()(
				{
					layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(1)}},
					backgroundColor = theme.Light.border,
				},
				) {}
				continue
			}

			if len(block.marker) > 0 {
				if clay.UI()(
				{
					layout = {
						sizing = {
							width = clay.SizingFixed(24),
							height = clay.SizingFixed(block.line_height),
						},
						childAlignment = {y = .Center},
					},
				},
				) {
					clay.Text(
						block.marker,
						{
							fontSize = block.font_size,
							textColor = theme.Light.text,
							wrapMode = .None,
						},
					)
				}
			}

			if clay.UI()(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .TopToBottom,
					padding = {
						u16(block.padding + (block.quote ? 10 : 0)),
						u16(block.padding),
						u16(block.top_padding),
						u16(block.bottom_padding),
					},
				},
				backgroundColor = block.code ? theme.Gray_100 : (block.active ? theme.Cyan_50 : clay.Color{}),
				cornerRadius = block.code ? clay.CornerRadius{topLeft = block.top_padding > 0 ? 6 : 0, topRight = block.top_padding > 0 ? 6 : 0, bottomLeft = block.bottom_padding > 0 ? 6 : 0, bottomRight = block.bottom_padding > 0 ? 6 : 0} : clay.CornerRadiusAll(4),
				border = block.quote ? clay.BorderElementConfig{color = theme.Gray_300, width = {2, 0, 0, 0, 0}} : clay.BorderElementConfig{},
			},
			) {
				for line, line_index in block.lines {
					if clay.UI()(
					{
						layout = {
							sizing = {
								width = clay.SizingGrow(),
								height = clay.SizingFixed(block.line_height),
							},
							layoutDirection = .LeftToRight,
							childAlignment = {y = .Center},
						},
					},
					) {
						for span in line.spans {
							if len(span.text) == 0 do continue
							if clay.UI()(
							{
								layout = {
									sizing = {width = clay.SizingFit(), height = clay.SizingFit()},
								},
								backgroundColor = span.selected ? theme.Light.selection : (span.code ? theme.Gray_100 : clay.Color{}),
								cornerRadius = clay.CornerRadiusAll(2),
							},
							) {
								clay.Text(
									span.text,
									{
										fontId = span.style,
										fontSize = block.font_size,
										textColor = span.color,
										wrapMode = .None,
									},
								)
							}
						}
						if block.active && options.show_caret {
							last := line_index == len(block.lines) - 1
							if options.cursor >= line.source_start &&
							   (options.cursor < line.source_end ||
									   (last && options.cursor == line.source_end)) {
								x, caret_y, caret_height := caret_geometry(block, line, options)
								if clay.UI(clay.ID("Caret"))(
								{
									layout = {
										sizing = {
											width = clay.SizingFixed(2),
											height = clay.SizingFixed(caret_height),
										},
									},
									floating = {
										attachTo = .Parent,
										offset = {x, caret_y},
										zIndex = 1,
										pointerCaptureMode = .Passthrough,
										clipTo = .AttachedParent,
									},
									backgroundColor = theme.Light.text,
								},
								) {}
							}
						}
					}
				}
			}
		}
	}
}

append_markdown_blocks :: proc(
	node: ^commonmark.Node,
	layout: ^DocumentLayout,
	options: RenderOptions,
	indent: f32,
	marker: string,
	quote: bool,
) {
	kind := commonmark.node_get_type(node)
	#partial switch kind {
	case .Document, .Item:
		if kind == .Item && commonmark.node_first_child(node) == nil {
			block := RenderBlock{node = node, marker = marker, indent = indent, font_size = 15, line_height = 24, height = 24, source_line = int(commonmark.node_get_start_line(node)), source_end_line = int(commonmark.node_get_end_line(node))}
			append(&layout.blocks, block)
			layout.height += block.height
			return
		}
		first := true
		for child := commonmark.node_first_child(node);
		    child != nil;
		    child = commonmark.node_next(child) {
			append_markdown_blocks(
				child,
				layout,
				options,
				indent + (first ? 0 : (len(marker) > 0 ? 24 : 0)),
				first ? marker : "",
				quote,
			)
			first = false
		}
		return
	case .List:
		ordered := commonmark.node_get_list_type(node) == .Ordered
		number := int(commonmark.node_get_list_start(node))
		for item := commonmark.node_first_child(node);
		    item != nil;
		    item = commonmark.node_next(item) {
			label := ordered ? fmt.tprintf("%d.", number) : "•"
			append_markdown_blocks(
				item,
				layout,
				options,
				indent + (len(marker) > 0 ? 24 : 0),
				label,
				quote,
			)
			number += 1
		}
		return
	case .Block_Quote:
		for child := commonmark.node_first_child(node);
		    child != nil;
		    child = commonmark.node_next(child) {
			append_markdown_blocks(child, layout, options, indent + 12, marker, true)
		}
		return
	}

	block := RenderBlock {
		font_size       = 15,
		line_height     = 24,
		indent          = indent,
		marker          = marker,
		quote           = quote,
		spacing         = 12,
		node            = node,
		source_line     = int(commonmark.node_get_start_line(node)),
		source_end_line = int(commonmark.node_get_end_line(node)),
	}
	spans := make([dynamic]TextSpan, context.temp_allocator)
	#partial switch kind {
	case .Heading:
		sizes := [6]u16{30, 24, 20, 18, 16, 15}
		level := clamp(int(commonmark.node_get_heading_level(node)), 1, 6)
		block.font_size = sizes[level - 1]
		block.line_height = f32(block.font_size) + 10
		collect_inline(node, &spans, 1, theme.Light.text)
	case .Paragraph:
		collect_inline(node, &spans, 0, quote ? theme.Gray_600 : theme.Light.text)
	case .Code_Block, .HTML_Block:
		block.code = true
		block.font_size = 13
		block.line_height = 21
		block.padding = 10
		block.top_padding = 10
		block.bottom_padding = 10
		literal := strings.trim_right(string(commonmark.node_get_literal(node)), "\r\n")
		append(&spans, TextSpan{text = literal, color = theme.Gray_800})
	case .Thematic_Break:
		block.rule = true
		block.height = 13
		append(&layout.blocks, block)
		layout.height += block.height
		return
	case:
		return
	}
	width := max(
		1,
		options.width - indent - block.padding * 2 - (quote ? 10 : 0) - (len(marker) > 0 ? 24 : 0),
	)
	block.lines = wrap_inline(spans[:], width, block.font_size, options, block.code)
	block.height =
		f32(len(block.lines)) * block.line_height +
		block.top_padding +
		block.bottom_padding +
		block.spacing
	append(&layout.blocks, block)
	layout.height += block.height
}

collect_inline :: proc(
	node: ^commonmark.Node,
	spans: ^[dynamic]TextSpan,
	style: u16,
	color: clay.Color,
) {
	style := style
	color := color
	kind := commonmark.node_get_type(node)
	#partial switch kind {
	case .Text, .Code, .HTML_Inline:
		append(
			spans,
			TextSpan {
				text = string(commonmark.node_get_literal(node)),
				style = style,
				color = color,
				code = kind == .Code,
				source_line = int(commonmark.node_get_start_line(node)),
				source_column = int(commonmark.node_get_start_column(node)),
			},
		)
		return
	case .Soft_Break:
		append(spans, TextSpan{text = " ", style = style, color = color})
		return
	case .Line_Break:
		append(spans, TextSpan{text = "\n", style = style, color = color})
		return
	case .Strong:
		style |= 1
	case .Emph:
		style |= 2
	case .Link:
		color = theme.Cyan_700
	case .Image:
		append(spans, TextSpan{text = "[Image: ", color = theme.Gray_600})
	}
	for child := commonmark.node_first_child(node);
	    child != nil;
	    child = commonmark.node_next(child) {
		collect_inline(child, spans, style, color)
	}
	if kind == .Image do append(spans, TextSpan{text = "]", color = theme.Gray_600})
}

span_width :: proc(span: TextSpan, size: u16, options: RenderOptions) -> f32 {
	if options.measure == nil do return f32(len(span.text)) * f32(size) * 0.55
	config := clay.TextElementConfig {
		fontId   = span.style,
		fontSize = size,
	}
	text := clay.StringSlice {
		length    = i32(len(span.text)),
		chars     = raw_data(span.text),
		baseChars = raw_data(span.text),
	}
	return options.measure(text, &config, options.user_data).width
}

wrap_inline :: proc(
	spans: []TextSpan,
	width: f32,
	size: u16,
	options: RenderOptions,
	preserve_space: bool,
) -> [dynamic]RenderLine {
	lines := make([dynamic]RenderLine, context.temp_allocator)
	append(&lines, RenderLine{spans = make([dynamic]TextSpan, context.temp_allocator)})
	x: f32
	for span in spans {
		at := 0
		for at < len(span.text) {
			if span.text[at] == '\n' {
				append(&lines, RenderLine{spans = make([dynamic]TextSpan, context.temp_allocator)})
				x = 0
				at += 1
				continue
			}
			space := span.text[at] == ' ' || span.text[at] == '\t'
			end := at + 1
			for end < len(span.text) && span.text[end] != '\n' && ((span.text[end] == ' ' || span.text[end] == '\t') == space) do end += 1
			piece := span
			piece.text = span.text[at:end]
			piece.source_column = span.source_column + at
			at = end
			if space && !preserve_space && !span.code {
				if x == 0 do continue
				piece.text = " "
			}
			w := span_width(piece, size, options)
			if x > 0 && x + w > width {
				append(&lines, RenderLine{spans = make([dynamic]TextSpan, context.temp_allocator)})
				x = 0
				if space && !preserve_space && !span.code do continue
			}
			if w > width {
				// Break a long token only at UTF-8 character boundaries.
				start, cursor := 0, 0
				for cursor < len(piece.text) {
					next := cursor + 1
					for next < len(piece.text) && (piece.text[next] & 0xC0) == 0x80 do next += 1
					part := piece
					part.text = piece.text[start:next]
					part.source_column = piece.source_column + start
					if cursor > start && span_width(part, size, options) > width {
						part.text = piece.text[start:cursor]
						append(&lines[len(lines) - 1].spans, part)
						append(
							&lines,
							RenderLine{spans = make([dynamic]TextSpan, context.temp_allocator)},
						)
						start = cursor
						x = 0
					}
					cursor = next
				}
				piece.text = piece.text[start:]
				piece.source_column += start
				w = span_width(piece, size, options)
			}
			append(&lines[len(lines) - 1].spans, piece)
			x += w
		}
	}
	return lines
}

// Measure each styled span so selections do not change the caret position.
caret_geometry :: proc(block: RenderBlock, line: RenderLine, options: RenderOptions) -> (x, y, height: f32) {
	for span in line.spans {
		prefix := span
		start := line.source_base + max(0, span.source_column-1)
		count := clamp(options.cursor-start, 0, len(span.text))
		prefix.text = span.text[:count]
		x += span_width(prefix, block.font_size, options)
		if options.cursor < start+len(span.text) do break
	}
	height = f32(block.font_size)
	y = max(0, (block.line_height - height) / 2)
	return
}
