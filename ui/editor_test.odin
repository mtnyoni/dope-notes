package ui

import buffer "../buffer"
import font "../font"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
editor_text_is_independent_of_gap_position :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(64)}
	defer buffer.destroy_gap_buffer(&ed.buf)
	buffer.insert(&ed.buf, 0, "hello café\nworld")
	positions := [3]int{0, 6, buffer.text_len(&ed.buf)}
	for position in positions {
		buffer.shift_gap_to(&ed.buf, position)
		testing.expect_value(t, editor_text(&ed), "hello café\nworld")
	}
}

@(test)
editor_newlines_wrapping_and_vertical_navigation :: proc(t: ^testing.T) {
	face := font.open("font/Roboto-Regular.ttf")
	testing.expect(t, face != nil)
	if face == nil do return
	defer font.close(face)
	ed := EditorState{buf = buffer.make_gap_buffer(64), focused = true, face = face, content_width = 1000}
	defer buffer.destroy_gap_buffer(&ed.buf)
	buffer.insert(&ed.buf, 0, "hello\nworld")
	ed.cursor = 3
	e := sdl.Event{}
	e.type = .KEY_DOWN
	e.key.key = sdl.K_DOWN
	editor_handle_event(&ed, &e)
	testing.expect(t, ed.cursor >= 6 && ed.cursor <= 11)
	e.key.key = sdl.K_UP
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.cursor, 3)
	ed.cursor = buffer.text_len(&ed.buf)
	e.key.key = sdl.K_RETURN
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), "hello\nworld\n")
	lines := editor_lines(&ed, editor_text(&ed))
	testing.expect_value(t, len(lines), 3)
	testing.expect_value(t, lines[2].start, ed.cursor)
	testing.expect_value(t, editor_cursor_line(lines[:], ed.cursor), 2)

	// Force a wrap between two UTF-8 characters, never inside an encoded rune.
	ed.content_width = editor_text_width(&ed, "é")
	wrapped := editor_lines(&ed, "éé")
	testing.expect_value(t, len(wrapped), 2)
	testing.expect_value(t, wrapped[0].end, 2)
	testing.expect_value(t, wrapped[1].start, 2)
	testing.expect_value(t, editor_cursor_line(wrapped[:], 2), 1)
}
