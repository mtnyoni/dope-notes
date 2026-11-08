package ui

import buffer "../buffer"
import font "../font"
import markdown "../markdown"
import commonmark "vendor:commonmark"

// Each opened note owns its editor state, keeping edits and cursor position
// when the user switches to another note and back.
EditorDocuments :: struct {
	editors: map[string]^EditorState,
}

editor_open_note :: proc(documents: ^EditorDocuments, note: ^markdown.NoteFile, face: ^font.Font) -> ^EditorState {
	if note == nil do return nil
	if ed, found := documents.editors[note.path]; found {
		return ed
	}
	if documents.editors == nil do documents.editors = make(map[string]^EditorState)

	ed := new(EditorState)
	ed^ = EditorState {
		buf = buffer.make_gap_buffer(max(64, len(note.content))),
		face = face,
		focused = true,
		markdown_dirty = true,
		reveal_cursor = true,
	}
	buffer.insert(&ed.buf, 0, note.content)
	buffer.shift_gap_to(&ed.buf, 0)
	documents.editors[note.path] = ed
	return ed
}

editor_close_documents :: proc(documents: ^EditorDocuments) {
	for _, ed in documents.editors {
		editor_destroy_state(ed)
		free(ed)
	}
	delete(documents.editors)
	documents^ = {}
}

editor_destroy_state :: proc(ed: ^EditorState) {
	if ed.markdown_ast != nil do commonmark.node_free(ed.markdown_ast)
	buffer.destroy_gap_buffer(&ed.buf)
	ed^ = {}
}
