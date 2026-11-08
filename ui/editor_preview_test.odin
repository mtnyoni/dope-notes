package ui

import font "../font"
import markdown "../markdown"
import clay_ui "./clay"
import "core:testing"
import clay "shared:clay"
import commonmark "vendor:commonmark"
import sdl "vendor:sdl3"

// Runs in the existing layout test's Clay context.
editor_markdown_preview_test :: proc(t: ^testing.T) {
	face := font.open("font/Roboto-Regular.ttf")
	assert(face != nil)
	defer font.close(face)
	clay.SetMeasureTextFunction(clay_ui.measure_text, face)
	defer clay.SetMeasureTextFunction(sidebar_test_measure, nil)
	documents: EditorDocuments
	defer editor_close_documents(&documents)
	note := markdown.NoteFile{path = "preview.md", content = transmute([]u8)string("# A heading\n\nA **bold** paragraph.")}
	ed := editor_open_note(&documents, &note, face)
	editor_test_scroll_frame(ed)
	editor_test_scroll_frame(ed)
	testing.expect_value(t, ed.view_mode, EditorViewMode.Preview)
	testing.expect(t, ed.preview_ast != nil && !ed.preview_dirty)
	testing.expect(t, clay.GetElementData(clay.ID("MarkdownBlock", 0)).found)
	testing.expect(t, !clay.GetElementData(clay.ID("Caret")).found)

	editor_toggle_preview(ed)
	editor_test_scroll_frame(ed)
	testing.expect(t, ed.focused && ed.view_mode == .Source)
	testing.expect(t, clay.GetElementData(clay.ID("Caret")).found)
	e := sdl.Event{}
	e.type = .TEXT_INPUT
	e.text.text = "Changed "
	editor_handle_event(ed, &e)
	testing.expect(t, ed.preview_dirty)
	editor_toggle_preview(ed)
	editor_test_scroll_frame(ed)
	testing.expect(t, !ed.preview_dirty && !ed.focused)
	first := commonmark.node_first_child(ed.preview_ast)
	literal := string(commonmark.node_get_literal(commonmark.node_first_child(first)))
	testing.expect_value(t, literal, "Changed # A heading")
}
