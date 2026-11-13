package ui

import buffer "../buffer"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
list_enter_continues_splits_and_exits :: proc(t: ^testing.T) {
	cases := []struct{source, expected: string, cursor: int}{
		{"- First", "- First\n- ", 7},
		{"3. First", "3. First\n4. ", 8},
		{"+ First", "+ First\n+ ", 7},
		{"2) First", "2) First\n3) ", 8},
		{"- First\n  - Nested", "- First\n  - Nested\n  - ", 18},
		{"- ", "", 2},
		{"1. ", "", 3},
		{"- Hello world", "- Hello\n-  world", 7},
		{"```\n- code\n```", "```\n- code\n\n```", 10},
	}
	for c in cases {
		ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true, cursor = c.cursor}
		buffer.insert(&ed.buf, 0, c.source)
		e := sdl.Event{}
		e.type = .KEY_DOWN
		e.key.key = sdl.K_RETURN
		editor_handle_event(&ed, &e)
		testing.expect_value(t, editor_text(&ed), c.expected)
		editor_destroy_state(&ed)
	}
}

@(test)
list_home_left_and_backspace_respect_hidden_marker :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(64), focused = true, cursor = 12}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "- One\n- Two")
	ed.cursor = buffer.text_len(&ed.buf)
	e := sdl.Event{}
	e.type = .KEY_DOWN
	e.key.key = sdl.K_HOME
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.cursor, 8)
	e.key.key = sdl.K_LEFT
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.cursor, 5)
	e.key.key = sdl.K_RIGHT
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.cursor, 8)
	e.key.key = sdl.K_BACKSPACE
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), "- One\nTwo")
	testing.expect_value(t, ed.cursor, 6)
}

@(test)
list_delete_merges_visible_item_text :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(64), focused = true, cursor = 5}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "- One\n- Two")
	e := sdl.Event{}
	e.type = .KEY_DOWN
	e.key.key = sdl.K_DELETE
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), "- OneTwo")
}
