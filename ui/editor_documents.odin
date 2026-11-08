package ui

import buffer "../buffer"
import font "../font"
import notes "../notes"

// Each opened note owns its editor state, keeping edits and cursor position
// when the user switches to another note and back.
EditorDocuments :: struct {
	editors: map[string]^EditorState,
}

editor_open_note :: proc(documents: ^EditorDocuments, note: ^notes.Note, face: ^font.Font) -> ^EditorState {
	if note == nil do return nil
	if ed, found := documents.editors[note.slug]; found {
		return ed
	}
	if documents.editors == nil do documents.editors = make(map[string]^EditorState)

	ed := new(EditorState)
	ed^ = EditorState {
		buf = buffer.make_gap_buffer(max(64, len(note.title) + 2 + len(note.content))),
		face = face,
		focused = true,
		reveal_cursor = true,
	}
	buffer.insert(&ed.buf, 0, note.title)
	buffer.insert(&ed.buf, len(note.title), "\n\n")
	buffer.insert(&ed.buf, len(note.title) + 2, note.content)
	buffer.shift_gap_to(&ed.buf, 0)
	documents.editors[note.slug] = ed
	return ed
}

editor_close_documents :: proc(documents: ^EditorDocuments) {
	for _, ed in documents.editors {
		buffer.destroy_gap_buffer(&ed.buf)
		free(ed)
	}
	delete(documents.editors)
	documents^ = {}
}
