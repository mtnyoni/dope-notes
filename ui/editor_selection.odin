package ui

import buffer "../buffer"

editor_delete_selection :: proc(ed: ^EditorState) -> bool {
	length := buffer.text_len(&ed.buf)
	start := clamp(min(ed.selection.start, ed.selection.end), 0, length)
	end := clamp(max(ed.selection.start, ed.selection.end), 0, length)
	if start == end { ed.selection = {}; return false }
	buffer.remove(&ed.buf, start, end-start)
	ed.cursor = start
	ed.selection = {}
	ed.markdown_dirty = true
	return true
}
