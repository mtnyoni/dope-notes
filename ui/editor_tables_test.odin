package ui

import buffer "../buffer"
import markdown "../markdown"
import "core:strings"
import "core:testing"
import sdl "vendor:sdl3"
import clay "shared:clay"

@(test)
table_editing_preserves_grid_and_protects_boundaries :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(256), focused = true, content_width = 400}
	defer editor_destroy_state(&ed)
	text := "| Name | Status |\n| --- | :---: |\n| Apex | Active |"
	buffer.insert(&ed.buf, 0, text)
	prepared := editor_table_layout(&ed)
	cell := prepared.blocks[1].table_cells[0]
	ed.cursor = cell.source_start
	e := sdl.Event{}
	e.type = .KEY_DOWN
	e.key.key = sdl.K_BACKSPACE
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), text)
	ed.cursor = cell.source_end
	e.key.key = sdl.K_DELETE
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), text)
	// Select all applies to this cell, not to the Markdown document.
	e.key.key = sdl.K_A
	e.key.mod = {.LCTRL}
	editor_handle_event(&ed, &e)
	e.type = .TEXT_INPUT
	e.text.text = "New|Project"
	editor_handle_event(&ed, &e)
	testing.expect(t, strings.contains(editor_text(&ed), "| New\\|Project | Active |"))
	prepared = editor_table_layout(&ed)
	testing.expect(t, prepared.blocks[1].table)
	testing.expect_value(t, len(prepared.blocks[1].table_cells), 2)
	// Tab moves to the next cell without changing the source.
	before := strings.clone(editor_text(&ed))
	defer delete(before)
	e.type = .KEY_DOWN
	e.key.mod = {}
	e.key.key = sdl.K_TAB
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.cursor, prepared.blocks[1].table_cells[1].source_start)
	testing.expect_value(t, editor_text(&ed), before)
	// Enter moves down a row; it never inserts a newline inside the table.
	ed.cursor = prepared.blocks[0].table_cells[1].source_start
	e.key.key = sdl.K_RETURN
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.cursor, prepared.blocks[1].table_cells[1].source_start)
	testing.expect_value(t, editor_text(&ed), before)
}

@(test)
table_hit_testing_respects_alignment_and_empty_cells :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true, content_width = 400}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "| Left | Right |\n| :--- | ---: |\n| abc | |")
	prepared := editor_table_layout(&ed)
	block := prepared.blocks[1]
	options := editor_markdown_options(&ed)
	start := markdown.table_pick_cursor(block, 8, 12, options)
	testing.expect_value(t, start, block.table_cells[0].source_start)
	end := markdown.table_pick_cursor(block, 190, 12, options)
	testing.expect_value(t, end, block.table_cells[0].source_end)
	empty := markdown.table_pick_cursor(block, 250, 12, options)
	testing.expect_value(t, empty, block.table_cells[1].source_start)
	ed.cursor = empty
	e := sdl.Event{}
	e.type = .TEXT_INPUT
	e.text.text = "New"
	editor_handle_event(&ed, &e)
	prepared = editor_table_layout(&ed)
	testing.expect(t, prepared.blocks[1].table)
	cell := prepared.blocks[1].table_cells[1]
	testing.expect_value(t, editor_text(&ed)[cell.source_start:cell.source_end], "New")
}

// Called within the sidebar integration test's existing GUI context.
editor_table_mouse_test :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "| Name | State |\n| --- | --- |\n| abc | active |")
	for _ in 0..<2 do editor_test_scroll_frame(&ed)
	prepared := editor_prepare_layout(&ed)
	block := prepared.rendered.blocks[1]
	cell := block.table_cells[0]
	bounds := clay.GetElementData(clay.ID(EDITOR_ID)).boundingBox
	x := bounds.x+EDITOR_PADDING+8+f32(EDITOR_FONT_SIZE)*0.55
	y := bounds.y+EDITOR_PADDING+prepared.rendered.blocks[0].height+20
	e := sdl.Event{}
	e.type = .MOUSE_BUTTON_DOWN
	e.button.button = sdl.BUTTON_LEFT
	e.button.x, e.button.y = x, y
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.cursor, cell.source_start+1)
	editor_test_scroll_frame(&ed)
	testing.expect(t, clay.GetElementData(clay.ID("Caret")).found)
	// A drag outside the cell cannot select its structural pipe separators.
	e.type = .MOUSE_MOTION
	e.motion.x, e.motion.y = x+1000, y
	editor_handle_event(&ed, &e)
	testing.expect_value(t, ed.selection.end, cell.source_end)
	e.type = .MOUSE_BUTTON_UP
	e.button.button = sdl.BUTTON_LEFT
	e.button.x, e.button.y = x+1000, y
	editor_handle_event(&ed, &e)
	e.type = .TEXT_INPUT
	e.text.text = "New"
	editor_handle_event(&ed, &e)
	prepared = editor_prepare_layout(&ed)
	testing.expect(t, prepared.rendered.blocks[1].table)
	testing.expect(t, strings.contains(editor_text(&ed), "| aNew | active |"))
}

@(test)
deleting_escaped_pipe_preserves_table_columns :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true, content_width = 400}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "| A | B |\n| --- | --- |\n|x\\||y|")
	layout := editor_table_layout(&ed)
	ed.cursor = layout.blocks[1].table_cells[0].source_end
	e := sdl.Event{}
	e.type = .KEY_DOWN
	e.key.key = sdl.K_BACKSPACE
	editor_handle_event(&ed, &e)
	testing.expect(t, strings.has_suffix(editor_text(&ed), "|x|y|"))
	layout = editor_table_layout(&ed)
	testing.expect_value(t, len(layout.blocks[1].table_cells), 2)
}
