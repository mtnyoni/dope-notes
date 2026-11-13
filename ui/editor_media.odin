package ui

import buffer "../buffer"
import media "../media"
import "core:fmt"
import "core:strings"
import sdl "vendor:sdl3"
import clay "shared:clay"

editor_handle_media_event :: proc(ed: ^EditorState, event: ^sdl.Event) -> bool {
	if ed.note_path == "" do return false
	if event.type == .DROP_FILE && event.drop.data != nil {
		viewport := clay.GetElementData(clay.ID(DOCUMENT_SCROLL_ID))
		if viewport.found && !scroll_contains(viewport.boundingBox, {event.drop.x, event.drop.y}) do return true
		editor_pick_cursor(ed, {event.drop.x, event.drop.y})
		if relative, ok := media.save_file(ed.note_path, string(event.drop.data)); ok {
			editor_insert_image(ed, relative)
		} else { fmt.eprintln("Could not attach dropped image:", event.drop.data) }
		return true
	}
	if !ed.focused || event.type != .KEY_DOWN || event.key.key != sdl.K_V || !(sdl.KMOD_CTRL & event.key.mod != {} || sdl.KMOD_GUI & event.key.mod != {}) do return false
	mimes := [3]cstring{"image/png", "image/jpeg", "image/bmp"}
	for mime in mimes {
		if !sdl.HasClipboardData(mime) do continue
		size: uint
		data := sdl.GetClipboardData(mime, &size)
		if data == nil do continue
		defer sdl.free(data)
		if size > media.MAX_IMAGE_BYTES { fmt.eprintln("Clipboard image is too large"); return true }
		if relative, ok := media.save_bytes(ed.note_path, (cast([^]u8)data)[:size]); ok {
			editor_insert_image(ed, relative)
		} else { fmt.eprintln("Could not attach clipboard image") }
		return true
	}
	if sdl.HasClipboardData("text/uri-list") {
		size: uint
		data := sdl.GetClipboardData("text/uri-list", &size)
		if data == nil do return false
		defer sdl.free(data)
		remaining := string((cast([^]u8)data)[:size])
		attached := false
		for raw in strings.split_lines_iterator(&remaining) {
			line := strings.trim_space(raw)
			if !strings.has_prefix(line, "file://") do continue
			path := editor_decode_file_uri(line[7:])
			if relative, ok := media.save_file(ed.note_path, path); ok {
				editor_insert_image(ed, relative)
				attached = true
			}
		}
		return attached
	}
	return false
}

editor_insert_image :: proc(ed: ^EditorState, relative: string) {
	text := editor_text(ed)
	prefix := ed.cursor > 0 && text[ed.cursor-1] != '\n' ? "\n\n" : ""
	insert := fmt.tprintf("%s![Image](%s)\n\n", prefix, relative)
	if _, selected := get_editor_selection(ed); selected {
		start := min(ed.selection.start, ed.selection.end)
		end := max(ed.selection.start, ed.selection.end)
		buffer.remove(&ed.buf, start, end-start)
		ed.cursor = start
	}
	buffer.insert(&ed.buf, ed.cursor, insert)
	ed.cursor += len(insert)
	ed.selection = {}
	ed.markdown_dirty = true
	ed.reveal_cursor = true
}

editor_decode_file_uri :: proc(path: string) -> string {
	bytes := make([dynamic]u8, context.temp_allocator)
	for at := 0; at < len(path); at += 1 {
		if path[at] == '%' && at+2 < len(path) {
			hi, lo := editor_hex_digit(path[at+1]), editor_hex_digit(path[at+2])
			if hi >= 0 && lo >= 0 { append(&bytes, u8(hi*16+lo)); at += 2; continue }
		}
		append(&bytes, path[at])
	}
	return string(bytes[:])
}

editor_hex_digit :: proc(byte: u8) -> int {
	if byte >= '0' && byte <= '9' do return int(byte-'0')
	if byte >= 'a' && byte <= 'f' do return int(byte-'a')+10
	if byte >= 'A' && byte <= 'F' do return int(byte-'A')+10
	return -1
}
