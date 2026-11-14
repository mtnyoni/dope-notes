package ui

import buffer "../buffer"
import "core:fmt"
import "core:strings"

FORMAT_BOLD :: u16(1)
FORMAT_ITALIC :: u16(2)
FORMAT_UNDERLINE :: u16(4)

editor_toggle_format :: proc(ed: ^EditorState, style: u16) {
	if ed == nil do return
	text := editor_text(ed)
	start := clamp(min(ed.selection.start, ed.selection.end), 0, len(text))
	end := clamp(max(ed.selection.start, ed.selection.end), 0, len(text))
	prefix, suffix := editor_format_markers(style)
	if start == end {
		if ed.format_run_style != 0 && ed.cursor == ed.format_run_end {
			_, closing := editor_format_markers(ed.format_run_style)
			ed.cursor += len(closing)
		}
		ed.format_run_style = 0
		ed.typing_style ~= style
	} else {
		opening, closing, wrapped := editor_find_format_wrapper(text, start, end, prefix, suffix)
		if wrapped {
			buffer.remove(&ed.buf, closing, len(suffix))
			buffer.remove(&ed.buf, opening, len(prefix))
			start -= len(prefix)
			end -= len(prefix)
		} else if end-start >= len(prefix)+len(suffix) && strings.has_prefix(text[start:end], prefix) && strings.has_suffix(text[start:end], suffix) {
			buffer.remove(&ed.buf, end-len(suffix), len(suffix))
			buffer.remove(&ed.buf, start, len(prefix))
			end -= len(prefix)+len(suffix)
		} else {
			buffer.insert(&ed.buf, end, suffix)
			buffer.insert(&ed.buf, start, prefix)
			start += len(prefix)
			end += len(prefix)
		}
		ed.selection = {start = start, end = end}
		ed.cursor = end
		ed.typing_style = 0
		ed.format_run_style = 0
		ed.markdown_dirty = true
	}
	ed.format_preview = true
	ed.focused = true
	ed.reveal_cursor = true
	buffer.shift_gap_to(&ed.buf, ed.cursor)
}

editor_insert_formatted_text :: proc(ed: ^EditorState, value: string) {
	selected := ed.selection.start != ed.selection.end
	editor_delete_selection(ed)
	if ed.typing_style == 0 {
		buffer.insert(&ed.buf, ed.cursor, value)
		ed.cursor += len(value)
		ed.format_run_style = 0
	} else if !selected && ed.format_run_style == ed.typing_style && ed.cursor == ed.format_run_end {
		buffer.insert(&ed.buf, ed.cursor, value)
		ed.cursor += len(value)
		ed.format_run_end = ed.cursor
	} else {
		prefix, suffix := editor_format_markers(ed.typing_style)
		insert := fmt.tprintf("%s%s%s", prefix, value, suffix)
		buffer.insert(&ed.buf, ed.cursor, insert)
		ed.cursor += len(prefix)+len(value)
		ed.format_run_style = ed.typing_style
		ed.format_run_start = ed.cursor-len(value)
		ed.format_run_end = ed.cursor
	}
	ed.markdown_dirty = true
}

editor_format_active :: proc(ed: ^EditorState, style: u16) -> bool {
	if ed == nil do return false
	if ed.typing_style & style != 0 do return true
	text := editor_text(ed)
	start := clamp(min(ed.selection.start, ed.selection.end), 0, len(text))
	end := clamp(max(ed.selection.start, ed.selection.end), 0, len(text))
	if start == end do return false
	prefix, suffix := editor_format_markers(style)
	_, _, wrapped := editor_find_format_wrapper(text, start, end, prefix, suffix)
	return wrapped
}

editor_format_markers :: proc(style: u16) -> (prefix, suffix: string) {
	switch style {
	case 1: return "**", "**"
	case 2: return "*", "*"
	case 3: return "***", "***"
	case 4: return "<u>", "</u>"
	case 5: return "<u>**", "**</u>"
	case 6: return "<u>*", "*</u>"
	case 7: return "<u>***", "***</u>"
	}
	return "", ""
}

editor_find_format_wrapper :: proc(text: string, start, end: int, prefix, suffix: string) -> (opening, closing: int, found: bool) {
	left, right := start, end
	opening, closing = -1, -1
	for left > 0 {
		stars := 0
		for at := left; at > 0 && text[at-1] == '*'; at -= 1 do stars += 1
		if (prefix != "*" || stars%2 == 1) && left >= len(prefix) && text[left-len(prefix):left] == prefix { opening = left-len(prefix); break }
		if left >= 3 && text[left-3:left] == "<u>" { left -= 3; continue }
		if left >= 2 && text[left-2:left] == "**" { left -= 2; continue }
		if text[left-1] == '*' { left -= 1; continue }
		break
	}
	for right < len(text) {
		stars := 0
		for at := right; at < len(text) && text[at] == '*'; at += 1 do stars += 1
		if (suffix != "*" || stars%2 == 1) && strings.has_prefix(text[right:], suffix) { closing = right; break }
		if strings.has_prefix(text[right:], "</u>") { right += 4; continue }
		if strings.has_prefix(text[right:], "**") { right += 2; continue }
		if text[right] == '*' { right += 1; continue }
		break
	}
	found = opening >= 0 && closing >= 0
	return
}

editor_backspace_format_run :: proc(ed: ^EditorState) -> bool {
	if ed.format_run_style == 0 || ed.cursor != ed.format_run_end || ed.selection.start != ed.selection.end || ed.cursor <= ed.format_run_start do return false
	previous := buffer.prev_rune_start(&ed.buf, ed.cursor)
	buffer.remove(&ed.buf, previous, ed.cursor-previous)
	ed.cursor = previous
	ed.format_run_end = previous
	if previous == ed.format_run_start {
		prefix, suffix := editor_format_markers(ed.format_run_style)
		buffer.remove(&ed.buf, previous, len(suffix))
		buffer.remove(&ed.buf, previous-len(prefix), len(prefix))
		ed.cursor -= len(prefix)
		ed.format_run_style = 0
	}
	ed.markdown_dirty = true
	return true
}
