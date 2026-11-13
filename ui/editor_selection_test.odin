package ui

import buffer "../buffer"
import "core:testing"
import clay "shared:clay"
import sdl "vendor:sdl3"

// Runs in the sidebar test's Clay context so GUI tests do not race each other.
editor_mouse_selection_test :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "hello café\nsecond line")
	for _ in 0..<2 do editor_test_scroll_frame(&ed)
	bounds := clay.GetElementData(clay.ID(EDITOR_ID)).boundingBox
	x := bounds.x+EDITOR_PADDING
	y := bounds.y+EDITOR_PADDING+12
	step := f32(EDITOR_FONT_SIZE)*0.55
	e := sdl.Event{}
	e.type = .MOUSE_BUTTON_DOWN
	e.button.button = sdl.BUTTON_LEFT
	e.button.x, e.button.y = x+step, y
	editor_handle_event(&ed, &e)
	testing.expect(t, ed.selection_dragging)
	testing.expect_value(t, ed.selection.start, 1)
	e.type = .MOUSE_MOTION
	e.motion.x, e.motion.y = x+5*step, y
	editor_handle_event(&ed, &e)
	text, selected := get_editor_selection(&ed)
	testing.expect(t, selected)
	testing.expect_value(t, text, "ello")
	e.type = .MOUSE_BUTTON_UP
	e.button.button = sdl.BUTTON_LEFT
	e.button.x, e.button.y = x+5*step, y
	editor_handle_event(&ed, &e)
	testing.expect(t, !ed.selection_dragging)
	// A new click collapses the previous selection, and dragging backwards works.
	e.type = .MOUSE_BUTTON_DOWN
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.selection.start, ed.selection.end)
	e.type = .MOUSE_MOTION
	e.motion.x, e.motion.y = x+step, y
	editor_handle_event(&ed, &e)
	text, selected = get_editor_selection(&ed)
	testing.expect_value(t, text, "ello")
	testing.expect(t, ed.selection.start > ed.selection.end)
	// Extend across a physical newline, ending in the second line.
	ed.selection.start = 1
	e.motion.x, e.motion.y = x+3*step, y+24
	editor_handle_event(&ed, &e)
	text, selected = get_editor_selection(&ed)
	testing.expect_value(t, text, "ello café\nsec")
	// Dragging past the editor edge retains a valid selection.
	e.motion.x, e.motion.y = x+10000, y+24
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.selection.end, buffer.text_len(&ed.buf))
	e.type = .WINDOW_FOCUS_LOST
	editor_handle_event(&ed, &e)
	testing.expect(t, !ed.selection_dragging)
	// Delete removes the selected text instead of a character after it.
	e.type = .KEY_DOWN
	e.key.key = sdl.K_DELETE
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), "h")
	testing.expect_value(t, ed.selection.start, ed.selection.end)
	// Typing replaces a selection, including one made backwards.
	ed.selection = {start = 1, end = 0}
	e.type = .TEXT_INPUT
	e.text.text = "é"
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), "é")
	testing.expect_value(t, ed.cursor, 2)
}
