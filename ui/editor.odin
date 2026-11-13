package ui

import buffer "../buffer"
import font "../font"
import markdown "../markdown"
import theme "../theme"
import clay_ui "./clay"
import "core:c"
import "core:strings"
import clay "shared:clay"
import commonmark "vendor:commonmark"
import sdl "vendor:sdl3"

EDITOR_ID :: "Editor"
EDITOR_FONT_SIZE :: 15
EDITOR_LINE_HEIGHT :: EDITOR_FONT_SIZE * 1.6
EDITOR_PADDING :: 4
CARET_WIDTH :: 2

EditorSelection :: struct {
	start: int,
	end:   int,
}

EditorState :: struct {
	markdown_ast:       ^commonmark.Node,
	markdown_dirty:     bool,
	buf:                buffer.GapBuffer,
	cursor:             buffer.BufferPosition,
	focused:            bool,
	font:               ^font.Font,
	content_width:      f32,
	first_visible_line: int,
	preferred_x:        f32,
	has_preferred_x:    bool,
	scroll:             ScrollState,
	reveal_cursor:      bool,
	selection:          EditorSelection,
}

EditorLine :: struct {
	start, end: int,
}

EditorTextLayout :: struct {
	text:        string,
	lines:       [dynamic]EditorLine,
	cursor_line: int,
	height:      f32,
	rendered:    markdown.DocumentLayout,
	caret_top:   f32,
	caret_height: f32,
}

Editor :: proc(ed: ^EditorState, prepared: ^EditorTextLayout) {
	if clay.UI(clay.ID(EDITOR_ID))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(EDITOR_PADDING),
		},
		cornerRadius = clay.CornerRadiusAll(8),
	},
	) {
		markdown.render_markdown_ast_to_clay(
			ed.markdown_ast,
			editor_markdown_options(ed),
			&prepared.rendered,
		)
	}
}

editor_handle_event :: proc(ed: ^EditorState, e: ^sdl.Event) {
	if e.type == .MOUSE_BUTTON_DOWN && e.button.button == sdl.BUTTON_LEFT {
		editor_pick_cursor(ed, {e.button.x, e.button.y})
		return
	}

	if !ed.focused do return
	buf := &ed.buf
	vertical := false

	#partial switch e.type {
	case .TEXT_INPUT:
		s := string(e.text.text)
		buffer.insert(buf, ed.cursor, s)
		ed.cursor += len(s)
		ed.markdown_dirty = true

	case .KEY_DOWN:
		if .RCTRL in e.key.mod || .LCTRL in e.key.mod {
			switch e.key.key {
			case sdl.K_A:
				ed.selection.start = 0
				ed.selection.end = buffer.text_len(buf)
				ed.cursor = ed.selection.end
				break

			case sdl.K_V:
				if sdl.HasClipboardText() {
					if text := sdl.GetClipboardText(); text != nil {
						defer sdl.free(text)

						s := string(cstring(text))
						buffer.insert(&ed.buf, ed.cursor, s)
						ed.cursor += len(s)
						ed.markdown_dirty = true
					}
				}
				break

			case sdl.K_C:
				if selection, ok := get_editor_selection(ed); ok {
					sdl.SetClipboardText(
						strings.clone_to_cstring(selection, context.temp_allocator),
					)
				}
				break
			}
		}

		switch e.key.key {
		case sdl.K_RETURN, sdl.K_KP_ENTER:
			buffer.insert(buf, ed.cursor, "\n")
			ed.cursor += 1
			ed.markdown_dirty = true

		case sdl.K_BACKSPACE:
			if selection, ok := get_editor_selection(ed); ok {
				start := min(ed.selection.start, ed.selection.end)
				end := max(ed.selection.start, ed.selection.end)

				buffer.remove(buf, start, end - start)
				ed.cursor = start
				ed.selection.start = start
				ed.selection.end = start
				ed.markdown_dirty = true
			} else if ed.cursor > 0 {
				p := buffer.prev_rune_start(buf, ed.cursor)
				buffer.remove(buf, p, ed.cursor - p)
				ed.cursor = p
				ed.selection.start = p
				ed.selection.end = p
				ed.markdown_dirty = true
			}

		case sdl.K_DELETE:
			n := buffer.next_rune_end(buf, ed.cursor) - ed.cursor
			buffer.remove(buf, ed.cursor, n)
			if n > 0 do ed.markdown_dirty = true

		case sdl.K_LEFT:
			ed.cursor = buffer.prev_rune_start(buf, ed.cursor)

		case sdl.K_RIGHT:
			ed.cursor = buffer.next_rune_end(buf, ed.cursor)

		case sdl.K_HOME:
			text := editor_text(ed)
			rows := markdown.source_lines(text)
			ed.cursor = rows[editor_physical_line(text, ed.cursor)].start

		case sdl.K_END:
			text := editor_text(ed)
			rows := markdown.source_lines(text)
			ed.cursor = rows[editor_physical_line(text, ed.cursor)].end

		case sdl.K_UP:
			editor_move_vertical(ed, -1)
			vertical = true

		case sdl.K_DOWN:
			editor_move_vertical(ed, 1)
			vertical = true
		}
	case:
		return
	}

	ed.reveal_cursor = true
	if !vertical do ed.has_preferred_x = false
	buffer.shift_gap_to(buf, ed.cursor)
}

editor_move_vertical :: proc(ed: ^EditorState, direction: int) {
	text := editor_text(ed)
	lines := editor_lines(ed, text)
	current := editor_cursor_line(lines[:], ed.cursor)
	if !ed.has_preferred_x {
		ed.preferred_x = editor_text_width(ed, text[lines[current].start:ed.cursor])
		ed.has_preferred_x = true
	}

	target := current + direction
	if target < 0 || target >= len(lines) do return
	line := lines[target]
	best := line.start
	distance := abs(ed.preferred_x)
	at := line.start
	for at < line.end {
		at = editor_next_utf8_boundary(text, at)
		// The boundary shared with a wrapped line belongs to that next line.
		if at == line.end && target + 1 < len(lines) && lines[target + 1].start == at do break
		x := editor_text_width(ed, text[line.start:at])
		if abs(x - ed.preferred_x) < distance {
			best = at
			distance = abs(x - ed.preferred_x)
		}
	}

	ed.cursor = best
}

editor_pick_cursor :: proc(ed: ^EditorState, mouse: clay.Vector2) {
	viewport := clay.GetElementData(clay.ID(DOCUMENT_SCROLL_ID))
	bounds := clay.GetElementData(clay.ID(EDITOR_ID))

	if !viewport.found || !bounds.found || !scroll_contains(viewport.boundingBox, mouse) || !scroll_contains(bounds.boundingBox, mouse) do return

	prepared := editor_prepare_layout(ed)
	rows := markdown.source_lines(prepared.text)
	y := mouse.y - bounds.boundingBox.y - EDITOR_PADDING
	x := mouse.x - bounds.boundingBox.x - EDITOR_PADDING
	top: f32
	position := len(prepared.text)
	for block in prepared.rendered.blocks {
		if y < top + block.height {
			source_row := rows[clamp(block.source_line - 1, 0, len(rows) - 1)]
			position = source_row.start
			blank_gap := false
			if block.node != nil && block.spacing > 0 && y >= top + block.height - block.spacing {
				next_index := int(commonmark.node_get_end_line(block.node))
				if next_index < len(rows) && rows[next_index].start == rows[next_index].end {
					position = rows[next_index].start
					blank_gap = true
				}
			}

			if !blank_gap && len(block.lines) > 0 {
				index := clamp(
					int((y - top - block.top_padding) / block.line_height),
					0,
					len(block.lines) - 1,
				)

				remaining :=
					x -
					block.indent -
					block.padding -
					(block.quote ? 10 : 0) -
					(len(block.marker) > 0 ? 24 : 0)
				position = source_row.end
				for span in block.lines[index].spans {
					width := markdown.span_width(
						span,
						block.font_size,
						editor_markdown_options(ed),
					)

					if remaining <= width {
						best, at := 0, 0
						distance := abs(remaining)
						for at < len(span.text) {
							at = editor_next_utf8_boundary(span.text, at)
							prefix := span
							prefix.text = span.text[:at]
							w := markdown.span_width(
								prefix,
								block.font_size,
								editor_markdown_options(ed),
							)

							if abs(w - remaining) < distance {
								best = at
								distance = abs(w - remaining)
							}
						}

						position = clamp(
							source_row.start + max(0, span.source_column - 1) + best,
							source_row.start,
							source_row.end,
						)
						break
					}

					remaining -= width
				}
			}
			break
		}
		top += block.height
	}

	for position > 0 && position < len(prepared.text) && (prepared.text[position] & 0xC0) == 0x80 do position -= 1
	ed.cursor = position
	ed.focused = true
	ed.has_preferred_x = false
	ed.reveal_cursor = true
	buffer.shift_gap_to(&ed.buf, ed.cursor)
}

editor_prepare_layout :: proc(ed: ^EditorState) -> EditorTextLayout {
	bounds := clay.GetElementData(clay.ID(EDITOR_ID))
	if bounds.found {
		ed.content_width = max(1, bounds.boundingBox.width - EDITOR_PADDING * 2 - CARET_WIDTH)
	}

	text := editor_text(ed)
	lines := editor_lines(ed, text)

	prepared := EditorTextLayout {
		text        = text,
		lines       = lines,
		cursor_line = editor_cursor_line(lines[:], ed.cursor),
		height      = f32(len(lines)) * EDITOR_LINE_HEIGHT + EDITOR_PADDING * 2,
	}

	if ed.markdown_ast == nil || ed.markdown_dirty {
		if ed.markdown_ast != nil do commonmark.node_free(ed.markdown_ast)
		ed.markdown_ast = commonmark.parse_document_from_string(text, {.Validate_UTF8})
		ed.markdown_dirty = false
	}

	active_line := -1
	if ed.focused do active_line = editor_physical_line(text, ed.cursor)
	prepared.rendered = markdown.prepare_live_markdown_layout(
		ed.markdown_ast,
		editor_markdown_options(ed),
		text,
		active_line,
	)

	prepared.height = prepared.rendered.height + EDITOR_PADDING * 2
	prepared.caret_top = -1
	y: f32
	for block in prepared.rendered.blocks {
		if block.active {
			for row, index in block.lines {
				last := index == len(block.lines) - 1
				if ed.cursor >= row.source_start &&
				   (ed.cursor < row.source_end || (last && ed.cursor == row.source_end)) {
					_, caret_y, caret_height := markdown.caret_geometry(block, row, editor_markdown_options(ed))
					prepared.caret_top = y + block.top_padding + f32(index) * block.line_height
					prepared.caret_height = caret_y + caret_height
				}
			}
		}

		y += block.height
	}

	return prepared
}

get_editor_selection :: proc(ed: ^EditorState) -> (string, bool) {
	if ed.selection.start == ed.selection.end {
		return "", false
	}

	text := editor_text(ed)
	buf_len := len(text)

	sel_min := min(ed.selection.start, ed.selection.end)
	sel_max := max(ed.selection.start, ed.selection.end)

	start := clamp(sel_min, 0, buf_len)
	end := clamp(sel_max, 0, buf_len)

	if start >= end {
		return "", false
	}

	return text[start:end], true
}

editor_lines :: proc(ed: ^EditorState, text: string) -> [dynamic]EditorLine {
	lines := make([dynamic]EditorLine, context.temp_allocator)

	current_content_width := ed.content_width
	if current_content_width <= 0 do current_content_width = 400

	start, at := 0, 0
	for at < len(text) {
		if text[at] == '\n' {
			append(&lines, EditorLine{start, at})
			at += 1
			start = at
			continue
		}

		next := editor_next_utf8_boundary(text, at)
		if at > start && editor_text_width(ed, text[start:next]) > current_content_width {
			append(&lines, EditorLine{start, at})
			start = at
		}
		at = next
	}
	// Retain an empty final line so a caret can follow a trailing newline.
	append(&lines, EditorLine{start, len(text)})
	return lines
}

editor_cursor_line :: proc(lines: []EditorLine, cursor: int) -> int {
	for line, i in lines {
		if cursor < line.end do return i
		if cursor == line.end && (i == len(lines) - 1 || lines[i + 1].start > cursor) do return i
	}

	return len(lines) - 1
}

editor_markdown_options :: proc(ed: ^EditorState) -> markdown.RenderOptions {
	return {
		width = ed.content_width > 0 ? ed.content_width : 400,
		measure = ed.font != nil ? clay_ui.measure_text : nil,
		user_data = ed.font,
		cursor = ed.cursor,
		show_caret = ed.focused,
		selection_start = ed.selection.start,
		selection_end = ed.selection.end,
	}
}

editor_physical_line :: proc(text: string, cursor: int) -> int {
	index := 0
	for i in 0 ..< min(cursor, len(text)) {
		if text[i] == '\n' do index += 1
	}
	return index
}

editor_text :: proc(ed: ^EditorState) -> string {
	left, right := buffer.get_strings(&ed.buf)
	bytes := make([]u8, len(left) + len(right), context.temp_allocator)
	copy(bytes, transmute([]u8)left)
	copy(bytes[len(left):], transmute([]u8)right)
	return string(bytes)
}

editor_text_width :: proc(ed: ^EditorState, text: string) -> f32 {
	if len(text) == 0 do return 0
	width, height: c.int
	if font.measure(
		   ed.font,
		   raw_data(text),
		   c.int(len(text)),
		   EDITOR_FONT_SIZE,
		   &width,
		   &height,
	   ) ==
	   0 {
		return 0
	}
	return f32(width)
}

// Returns the byte offset after the current UTF-8 character, skipping any
// continuation bytes. This prevents wrapping or cursor calculations from
// splitting characters such as é.
editor_next_utf8_boundary :: proc(text: string, pos: int) -> int {
	next_pos := min(pos + 1, len(text))
	for next_pos < len(text) && (text[next_pos] & 0xC0) == 0x80 do next_pos += 1
	return next_pos
}
