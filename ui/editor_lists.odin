package ui

import buffer "../buffer"
import markdown "../markdown"
import "core:strings"
import "core:fmt"
import commonmark "vendor:commonmark"

editor_insert_newline :: proc(ed: ^EditorState) {
	prefix, row, valid := editor_current_list(ed)
	if valid && ed.cursor >= row.start+prefix.content_start {
		text := editor_text(ed)
		if strings.trim_space(text[row.start+prefix.content_start:row.end]) == "" {
			buffer.remove(&ed.buf, row.start, prefix.content_start)
			ed.cursor = row.start
			return
		}
		insert := fmt.tprintf("\n%s", markdown.next_list_prefix(prefix))
		buffer.insert(&ed.buf, ed.cursor, insert)
		ed.cursor += len(insert)
		return
	}
	buffer.insert(&ed.buf, ed.cursor, "\n")
	ed.cursor += 1
}

editor_remove_list_prefix :: proc(ed: ^EditorState) -> bool {
	prefix, row, valid := editor_current_list(ed)
	if !valid || ed.cursor != row.start+prefix.content_start do return false
	buffer.remove(&ed.buf, row.start, prefix.content_start)
	ed.cursor = row.start
	ed.selection = {}
	return true
}

// List markers live in the file, but the caret stays in the visible item text.
editor_clamp_list_cursor :: proc(ed: ^EditorState) {
	prefix, row, valid := editor_current_list(ed)
	if valid do ed.cursor = max(ed.cursor, row.start+prefix.content_start)
}

editor_merge_next_list_item :: proc(ed: ^EditorState) -> bool {
	_, row, valid := editor_current_list(ed)
	if !valid || ed.cursor != row.end do return false
	text := editor_text(ed)
	if row.end >= len(text) do return false
	rows := markdown.source_lines(text)
	index := editor_physical_line(text, ed.cursor)+1
	next := rows[index]
	prefix := markdown.list_prefix(text[next.start:next.end])
	if !prefix.valid do return false
	buffer.remove(&ed.buf, ed.cursor, 1+prefix.content_start)
	return true
}

editor_current_list :: proc(ed: ^EditorState) -> (prefix: markdown.ListPrefix, row: markdown.SourceLine, valid: bool) {
	text := editor_text(ed)
	rows := markdown.source_lines(text)
	index := editor_physical_line(text, ed.cursor)
	row = rows[index]
	prefix = markdown.list_prefix(text[row.start:row.end])
	if !prefix.valid do return
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	valid = markdown.source_line_in_list(root, index+1)
	return
}
