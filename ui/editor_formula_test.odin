package ui

import buffer "../buffer"
import markdown "../markdown"
import "core:strings"
import "core:testing"
import sdl "vendor:sdl3"
import clay "shared:clay"

@(test)
formula_click_and_typing_edit_fraction_contents :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(256), focused = true, content_width = 600}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "$$\nP + \\frac{1}{2}\\rho v^2 = \\text{constant}\n$$")
	block, found := editor_current_formula(&ed)
	testing.expect(t, found)
	for glyph in block.formula.glyphs {
		if glyph.text != "1" do continue
		x := (ed.content_width-block.formula.width)/2+glyph.x+glyph.width*0.9
		y := (block.height-block.formula.height)/2+glyph.y+glyph.height/2
		ed.cursor = markdown.math_pick_cursor(block, x, y, ed.content_width)
		testing.expect_value(t, ed.cursor, glyph.source_end)
	}
	e := sdl.Event{}
	e.type = .TEXT_INPUT
	e.text.text = "3"
	editor_handle_event(&ed, &e)
	testing.expect(t, strings.contains(editor_text(&ed), "\\frac{13}{2}"))
	e.type = .KEY_DOWN
	e.key.key = sdl.K_BACKSPACE
	editor_handle_event(&ed, &e)
	testing.expect(t, strings.contains(editor_text(&ed), "\\frac{1}{2}"))
	block, found = editor_current_formula(&ed)
	for glyph in block.formula.glyphs {
		if glyph.text != "ρ" do continue
		ed.cursor = glyph.source_start
		e.key.key = sdl.K_RIGHT
		editor_handle_event(&ed, &e)
		testing.expect_value(t, ed.cursor, glyph.source_end)
		e.key.key = sdl.K_BACKSPACE
		editor_handle_event(&ed, &e)
	}
	testing.expect(t, !strings.contains(editor_text(&ed), "\\rho"))
	testing.expect(t, strings.contains(editor_text(&ed), "\\frac{1}{2}"))
}

@(test)
formula_replace_all_and_enter_preserve_delimiters :: proc(t: ^testing.T) {
	sources := []string{"$$\nx^2\n$$", "$$x^2$$"}
	for source in sources {
		ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true, content_width = 400}
		buffer.insert(&ed.buf, 0, source)
		block, ok := editor_current_formula(&ed)
		testing.expect(t, ok)
		ed.cursor = block.formula_source_start
		e := sdl.Event{}
		e.type = .KEY_DOWN
		e.key.key = sdl.K_A
		e.key.mod = {.LCTRL}
		editor_handle_event(&ed, &e)
		e.key.mod = {}
		e.key.key = sdl.K_BACKSPACE
		editor_handle_event(&ed, &e)
		_, empty_ok := editor_current_formula(&ed)
		testing.expect(t, empty_ok)
		e.type = .TEXT_INPUT
		e.text.text = "y"
		editor_handle_event(&ed, &e)
		text := editor_text(&ed)
		testing.expect(t, strings.has_prefix(text, "$$") && strings.has_suffix(text, "$$"))
		testing.expect(t, strings.contains(text, "y"))
		e.type = .KEY_DOWN
		e.key.key = sdl.K_RETURN
		editor_handle_event(&ed, &e)
		_, inside := editor_current_formula(&ed)
		testing.expect(t, !inside)
		testing.expect(t, strings.has_suffix(editor_text(&ed), "$$\n\n"))
		editor_destroy_state(&ed)
	}
}

editor_formula_mouse_test :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "$$x + \\frac{1}{2}$$")
	for _ in 0..<2 do editor_test_scroll_frame(&ed)
	prepared := editor_prepare_layout(&ed)
	block := prepared.rendered.blocks[0]
	bounds := clay.GetElementData(clay.ID(EDITOR_ID)).boundingBox
	for glyph in block.formula.glyphs {
		if glyph.text != "2" do continue
		x := bounds.x+EDITOR_PADDING+(ed.content_width-block.formula.width)/2+glyph.x+glyph.width*0.9
		y := bounds.y+EDITOR_PADDING+(block.height-block.formula.height)/2+glyph.y+glyph.height/2
		e := sdl.Event{}
		e.type = .MOUSE_BUTTON_DOWN
		e.button.button = sdl.BUTTON_LEFT
		e.button.x, e.button.y = x, y
		editor_handle_event(&ed, &e)
		testing.expect_value(t, ed.cursor, glyph.source_end)
		e.type = .MOUSE_BUTTON_UP
		editor_handle_event(&ed, &e)
		editor_test_scroll_frame(&ed)
		caret := clay.GetElementData(clay.ID("Caret"))
		testing.expect(t, caret.found)
		testing.expect_value(t, caret.boundingBox.height, f32(glyph.size))
		e.type = .TEXT_INPUT
		e.text.text = "3"
		editor_handle_event(&ed, &e)
		testing.expect_value(t, editor_text(&ed), "$$x + \\frac{1}{23}$$")
	}
}
