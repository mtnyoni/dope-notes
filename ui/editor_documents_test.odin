package ui

import buffer "../buffer"
import notes "../notes"
import "core:testing"

@(test)
switching_notes_loads_content_and_preserves_edits :: proc(t: ^testing.T) {
	documents: EditorDocuments
	defer editor_close_documents(&documents)
	first := notes.Note{slug = "first", title = "First", content = transmute([]u8)string("First body")}
	second := notes.Note{slug = "second", title = "Second", content = transmute([]u8)string("Second body\nAnother line")}

	ed := editor_open_note(&documents, &first, nil)
	testing.expect_value(t, editor_text(ed), "First\n\nFirst body")
	testing.expect_value(t, ed.cursor, 0)
	// Force buffer growth to check ownership when switching and closing.
	buffer.insert(&ed.buf, buffer.text_len(&ed.buf), " — an edit long enough to exceed the initial sixty-four-byte capacity of this buffer")
	ed.cursor = buffer.text_len(&ed.buf)
	buffer.shift_gap_to(&ed.buf, ed.cursor)
	ed.first_visible_line = 2
	ed.has_preferred_x = true
	ed.preferred_x = 30

	other := editor_open_note(&documents, &second, nil)
	testing.expect(t, other != ed)
	testing.expect_value(t, editor_text(other), "Second\n\nSecond body\nAnother line")
	testing.expect_value(t, other.cursor, 0)
	testing.expect_value(t, other.first_visible_line, 0)
	testing.expect(t, !other.has_preferred_x)

	reopened := editor_open_note(&documents, &first, nil)
	testing.expect(t, reopened == ed)
	testing.expect_value(t, editor_text(reopened), "First\n\nFirst body — an edit long enough to exceed the initial sixty-four-byte capacity of this buffer")
	testing.expect_value(t, reopened.cursor, buffer.text_len(&reopened.buf))
	testing.expect_value(t, reopened.first_visible_line, 2)
	testing.expect_value(t, editor_text(other), "Second\n\nSecond body\nAnother line")
	testing.expect(t, editor_open_note(&documents, nil, nil) == nil)
}
