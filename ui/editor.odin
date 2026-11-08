package ui

import buffer "../buffer"
import theme "../theme"
import clay "shared:clay"
import sdl "vendor:sdl3"

EditorState :: struct {
	buf:     buffer.GapBuffer,
	cursor:  buffer.BufferPosition,
	focused: bool,
}

EDITOR_ID :: "Editor"
Editor :: proc(ed: ^EditorState) {
	text_cfg := clay.TextElementConfig {
		fontId    = 0,
		fontSize  = 16,
		textColor = {20, 20, 20, 255},
	}
	left, right := buffer.get_strings(&ed.buf)

	if clay.UI(clay.ID(EDITOR_ID))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .LeftToRight,
			padding = clay.PaddingAll(12),
		},
		backgroundColor = theme.Cyan_100,
		cornerRadius = {8, 8, 8, 8},
	},
	) {
		if len(left) > 0 do clay.Text(left, text_cfg)

		if ed.focused {
			if clay.UI(clay.ID("Caret"))(
			{
				layout = {sizing = {width = clay.SizingFixed(2), height = clay.SizingFixed(16)}},
				backgroundColor = {20, 20, 20, 255},
			},
			) {}
		}

		if len(right) > 0 do clay.Text(right, text_cfg)
	}
}

editor_handle_event :: proc(ed: ^EditorState, e: ^sdl.Event) {
	if !ed.focused do return
	buf := &ed.buf

	#partial switch e.type {
	case .TEXT_INPUT:
		s := string(e.text.text)
		buffer.insert(buf, ed.cursor, s)
		ed.cursor += len(s)

	case .KEY_DOWN:
		switch e.key.key {
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
		}
	}

	// keep the gap at the cursor so get_strings splits exactly there
	buffer.shift_gap_to(buf, ed.cursor)
}
