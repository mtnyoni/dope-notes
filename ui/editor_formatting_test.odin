package ui

import buffer "../buffer"
import assets "../assets"
import clay "shared:clay"
import markdown "../markdown"
import "core:testing"
import commonmark "vendor:commonmark"
import sdl "vendor:sdl3"

@(test)
format_buttons_wrap_and_toggle_selected_text :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true, selection = {start = 0, end = 5}, cursor = 5}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "Hello")
	editor_toggle_format(&ed, FORMAT_BOLD)
	testing.expect_value(t, editor_text(&ed), "**Hello**")
	editor_toggle_format(&ed, FORMAT_ITALIC)
	testing.expect_value(t, editor_text(&ed), "***Hello***")
	editor_toggle_format(&ed, FORMAT_UNDERLINE)
	testing.expect_value(t, editor_text(&ed), "***<u>Hello</u>***")
	editor_toggle_format(&ed, FORMAT_BOLD)
	testing.expect_value(t, editor_text(&ed), "*<u>Hello</u>*")
	editor_toggle_format(&ed, FORMAT_UNDERLINE)
	testing.expect_value(t, editor_text(&ed), "*Hello*")
	editor_toggle_format(&ed, FORMAT_ITALIC)
	testing.expect_value(t, editor_text(&ed), "Hello")
}

@(test)
format_mode_styles_subsequent_typing_and_stops_on_toggle :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true}
	defer editor_destroy_state(&ed)
	editor_toggle_format(&ed, FORMAT_BOLD)
	e := sdl.Event{}
	e.type = .TEXT_INPUT
	e.text.text = "h"
	editor_handle_event(&ed, &e)
	e.text.text = "ello"
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), "**hello**")
	editor_toggle_format(&ed, FORMAT_BOLD)
	e.text.text = " plain"
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), "**hello** plain")
}

@(test)
underline_and_italic_render_on_the_active_line :: proc(t: ^testing.T) {
	text := "<u>*Hello*</u> plain"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	layout := markdown.prepare_live_markdown_layout(root, {width = 400, format_preview = true}, text, 0)
	found := false
	for block in layout.blocks {
		for line in block.lines {
			for span in line.spans {
				if span.text == "Hello" {
					found = true
					testing.expect_value(t, span.style, u16(6))
				}
				if span.text == "plain" do testing.expect_value(t, span.style, u16(0))
				testing.expect(t, span.text != "<u>" && span.text != "</u>")
			}
		}
	}
	testing.expect(t, found)
}

@(test)
backspacing_empty_format_run_keeps_valid_markdown :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(128), focused = true}
	defer editor_destroy_state(&ed)
	editor_toggle_format(&ed, FORMAT_BOLD)
	e := sdl.Event{}
	e.type = .TEXT_INPUT
	e.text.text = "x"
	editor_handle_event(&ed, &e)
	e.type = .KEY_DOWN
	e.key.key = sdl.K_BACKSPACE
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), "")
	e.type = .TEXT_INPUT
	e.text.text = "y"
	editor_handle_event(&ed, &e)
	testing.expect_value(t, editor_text(&ed), "**y**")
}

editor_toolbar_formatting_test :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(64), focused = true, selection = {start = 0, end = 5}, cursor = 5}
	defer editor_destroy_state(&ed)
	buffer.insert(&ed.buf, 0, "Hello")
	clay.SetPointerState({-1, -1}, false)
	clay.BeginLayout()
	EditorToolBar(nil, &ed)
	_ = clay.EndLayout(1.0/60.0)
	button := clay.GetElementData(clay.ID("ToolbarButton", u32(assets.Icon.LetterB))).boundingBox
	clay.SetPointerState({button.x+button.width/2, button.y+button.height/2}, true)
	clay.BeginLayout()
	EditorToolBar(nil, &ed)
	_ = clay.EndLayout(1.0/60.0)
	testing.expect_value(t, editor_text(&ed), "**Hello**")
	clay.SetPointerState({-1, -1}, false)
}
