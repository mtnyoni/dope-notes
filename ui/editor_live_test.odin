package ui

import font "../font"
import markdown "../markdown"
import clay_ui "./clay"
import "core:testing"
import clay "shared:clay"
import sdl "vendor:sdl3"

// Runs in the existing layout test's Clay context.
editor_live_markdown_test :: proc(t: ^testing.T) {
	face := font.open("font/Roboto-Regular.ttf")
	assert(face != nil)
	defer font.close(face)
	clay.SetMeasureTextFunction(clay_ui.measure_text, face)
	defer clay.SetMeasureTextFunction(sidebar_test_measure, nil)
	documents: EditorDocuments
	defer editor_close_documents(&documents)
	note := markdown.NoteFile{path = "live.md", content = transmute([]u8)string("# A heading\n\nA **bold** paragraph.")}
	ed := editor_open_note(&documents, &note, face)
	editor_test_scroll_frame(ed)
	editor_test_scroll_frame(ed)
	testing.expect(t, ed.focused && ed.markdown_ast != nil && !ed.markdown_dirty)
	testing.expect(t, clay.GetElementData(clay.ID("Caret")).found)
	prepared := editor_prepare_layout(ed)
	testing.expect(t, prepared.rendered.blocks[0].active)
	testing.expect_value(t, prepared.rendered.blocks[0].lines[0].spans[0].text, "# A heading")

	// Move through the empty source line into the paragraph.
	e := sdl.Event{}
	e.type = .KEY_DOWN
	e.key.key = sdl.K_DOWN
	editor_handle_event(ed, &e)
	editor_handle_event(ed, &e)
	editor_test_scroll_frame(ed)
	prepared = editor_prepare_layout(ed)
	testing.expect(t, !prepared.rendered.blocks[0].active)
	testing.expect_value(t, prepared.rendered.blocks[0].font_size, u16(30))
	active_count := 0
	for block in prepared.rendered.blocks {
		if block.active {
			active_count += 1
			testing.expect_value(t, block.source_line, 3)
			testing.expect_value(t, block.lines[0].spans[0].text, "A **bold** paragraph.")
		}
	}
	testing.expect_value(t, active_count, 1)

	e.type = .TEXT_INPUT
	e.text.text = "Changed "
	editor_handle_event(ed, &e)
	testing.expect(t, ed.markdown_dirty)
	editor_test_scroll_frame(ed)
	testing.expect(t, !ed.markdown_dirty && ed.focused)
	testing.expect_value(t, editor_text(ed), "# A heading\n\nChanged A **bold** paragraph.")

	// Clicking the formatted heading reveals its source and moves the caret.
	heading := clay.GetElementData(clay.ID("MarkdownBlock", 0)).boundingBox
	editor_pick_cursor(ed, {heading.x + 20, heading.y + 15})
	testing.expect_value(t, editor_physical_line(editor_text(ed), ed.cursor), 0)
	editor_test_scroll_frame(ed)
	prepared = editor_prepare_layout(ed)
	testing.expect(t, prepared.rendered.blocks[0].active)
	found_bold := false
	for block in prepared.rendered.blocks {
		if !block.active {
			for line in block.lines {
				for span in line.spans do found_bold = found_bold || (span.text == "bold" && span.style & 1 != 0)
			}
		}
	}
	testing.expect(t, found_bold)
	// The margin below a heading can activate the intervening blank line.
	heading = clay.GetElementData(clay.ID("MarkdownBlock", 0)).boundingBox
	editor_pick_cursor(ed, {heading.x + 10, heading.y + heading.height - 3})
	testing.expect_value(t, editor_physical_line(editor_text(ed), ed.cursor), 1)
	editor_test_scroll_frame(ed)
	prepared = editor_prepare_layout(ed)
	// Click inside bold rendered text: hidden ** delimiters must not offset
	// the source cursor into the wrong word when that line becomes editable.
	clicked := false
	for block, block_index in prepared.rendered.blocks {
		if block.source_line != 3 do continue
		rect := clay.GetElementData(clay.ID("MarkdownBlock", u32(block_index))).boundingBox
		x: f32
		for span in block.lines[0].spans {
			if span.text == "bold" {
				prefix := span
				prefix.text = "bo"
				x += markdown.span_width(prefix, block.font_size, editor_markdown_options(ed))
				source_rows := markdown.source_lines(prepared.text)
				expected := source_rows[2].start + span.source_column - 1 + 2
				editor_pick_cursor(ed, {rect.x + x, rect.y + 12})
				testing.expect_value(t, ed.cursor, expected)
				clicked = true
				break
			}
			x += markdown.span_width(span, block.font_size, editor_markdown_options(ed))
		}
	}
	testing.expect(t, clicked)

}
