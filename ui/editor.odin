package ui

import buffer "../buffer"
import font "../font"
import theme "../theme"
import "core:c"
import clay "shared:clay"
import sdl "vendor:sdl3"


EDITOR_ID :: "Editor"
EDITOR_FONT_SIZE :: 15
EDITOR_LINE_HEIGHT :: 24
EDITOR_PADDING :: 12
CARET_WIDTH :: 2

EditorState :: struct {
	buf:                buffer.GapBuffer,
	cursor:             buffer.BufferPosition,
	focused:            bool,
	face:               ^font.Font,
	content_width:      f32,
	first_visible_line: int,
	preferred_x:        f32,
	has_preferred_x:    bool,
}

EditorLine :: struct {
	start, end: int,
}

Editor :: proc(ed: ^EditorState) {
	bounds := clay.GetElementData(clay.ID(EDITOR_ID))
	if bounds.found {
		ed.content_width = max(1, bounds.boundingBox.width - EDITOR_PADDING * 2 - CARET_WIDTH)
	}

	text := editor_text(ed)
	lines := editor_lines(ed, text)
	cursor_line := editor_cursor_line(lines[:], ed.cursor)
	visible_count := len(lines)
	if bounds.found {
		visible_count = max(
			1,
			int((bounds.boundingBox.height - EDITOR_PADDING * 2) / EDITOR_LINE_HEIGHT),
		)
	}

	if cursor_line < ed.first_visible_line do ed.first_visible_line = cursor_line
	if cursor_line >= ed.first_visible_line + visible_count {
		ed.first_visible_line = cursor_line - visible_count + 1
	}
	ed.first_visible_line = clamp(ed.first_visible_line, 0, max(0, len(lines) - visible_count))

	text_cfg := clay.TextElementConfig {
		fontId    = 0,
		fontSize  = EDITOR_FONT_SIZE,
		textColor = theme.Light.text,
		wrapMode  = .None,
	}
	if clay.UI(clay.ID(EDITOR_ID))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .TopToBottom,
			padding = clay.PaddingAll(EDITOR_PADDING),
		},
		backgroundColor = theme.Cyan_100,
		cornerRadius = clay.CornerRadiusAll(8),
	},
	) {
		for i in ed.first_visible_line ..< min(len(lines), ed.first_visible_line + visible_count) {
			line := lines[i]
			if clay.UI(clay.ID("EditorLine", u32(i)))(
			{
				layout = {
					sizing = {
						width = clay.SizingGrow(),
						height = clay.SizingFixed(EDITOR_LINE_HEIGHT),
					},
				},
			},
			) {
				if line.end > line.start do clay.Text(text[line.start:line.end], text_cfg)
				if ed.focused && i == cursor_line {
					x := editor_text_width(ed, text[line.start:ed.cursor])
					// Floating geometry does not displace text or introduce a gap.
					if clay.UI(clay.ID("Caret"))(
					{
						layout = {
							sizing = {width = clay.SizingFixed(2), height = clay.SizingFixed(20)},
						},
						floating = {
							attachTo = .Parent,
							offset = {x, 0},
							zIndex = 1,
							pointerCaptureMode = .Passthrough,
						},
						backgroundColor = theme.Light.text,
					},
					) {}
				}
			}
		}
	}
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
		at = editor_next_boundary(text, at)
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

editor_handle_event :: proc(ed: ^EditorState, e: ^sdl.Event) {
	if !ed.focused do return
	buf := &ed.buf
	vertical := false

	#partial switch e.type {
	case .TEXT_INPUT:
		s := string(e.text.text)
		buffer.insert(buf, ed.cursor, s)
		ed.cursor += len(s)

	case .KEY_DOWN:
		switch e.key.key {
		case sdl.K_RETURN, sdl.K_KP_ENTER:
			buffer.insert(buf, ed.cursor, "\n")
			ed.cursor += 1

		case sdl.K_BACKSPACE:
			if ed.cursor > 0 {
				p := buffer.prev_rune_start(buf, ed.cursor)
				buffer.remove(buf, p, ed.cursor - p)
				ed.cursor = p
			}

		case sdl.K_DELETE:
			n := buffer.next_rune_end(buf, ed.cursor) - ed.cursor
			buffer.remove(buf, ed.cursor, n)

		case sdl.K_LEFT:
			ed.cursor = buffer.prev_rune_start(buf, ed.cursor)

		case sdl.K_RIGHT:
			ed.cursor = buffer.next_rune_end(buf, ed.cursor)

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

	if !vertical do ed.has_preferred_x = false
	buffer.shift_gap_to(buf, ed.cursor)
}

editor_text :: proc(ed: ^EditorState) -> string {
	left, right := buffer.get_strings(&ed.buf)
	bytes := make([]u8, len(left) + len(right), context.temp_allocator)
	copy(bytes, transmute([]u8)left)
	copy(bytes[len(left):], transmute([]u8)right)
	return string(bytes)
}

editor_next_boundary :: proc(text: string, pos: int) -> int {
	next_pos := min(pos + 1, len(text))
	for next_pos < len(text) && (text[next_pos] & 0xC0) == 0x80 do next_pos += 1
	return next_pos
}

editor_text_width :: proc(ed: ^EditorState, text: string) -> f32 {
	if len(text) == 0 do return 0
	width, height: c.int
	if font.measure(
		   ed.face,
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

editor_lines :: proc(ed: ^EditorState, text: string) -> [dynamic]EditorLine {
	lines := make([dynamic]EditorLine, context.temp_allocator)
	available := ed.content_width
	if available <= 0 do available = 400
	start, at := 0, 0
	for at < len(text) {
		if text[at] == '\n' {
			append(&lines, EditorLine{start, at})
			at += 1
			start = at
			continue
		}
		next := editor_next_boundary(text, at)
		if at > start && editor_text_width(ed, text[start:next]) > available {
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
