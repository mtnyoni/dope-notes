package markdown

import "core:encoding/json"
import "core:os"
import "core:strings"

// The first nonempty line is the title; Markdown heading markers are hidden.
// The next nonempty line supplies the sidebar preview.
note_preview :: proc(text: string) -> (title, description: string) {
	title = "Untitled"
	remaining := text
	found_title := false
	for raw in strings.split_lines_iterator(&remaining) {
		line := strings.trim_space(raw)
		if line == "" do continue
		if !found_title {
			line = strings.trim_left(line, "#")
			line = strings.trim_space(line)
			if line != "" do title = line
			found_title = true
		} else {
			description = line
			break
		}
	}
	return
}


parse_note_file :: proc(
	name, path: string,
	source: []u8,
	allocator := context.allocator,
) -> NoteFile {
	text := strings.trim_prefix(string(source), "\uFEFF")
	body := text
	metadata := ""
	remaining := text
	if first, ok := strings.split_lines_iterator(&remaining);
	   ok && strings.trim_space(first) == "---" {
		metadata_start := len(text) - len(remaining)
		for len(remaining) > 0 {
			line_start := len(text) - len(remaining)
			line, _ := strings.split_lines_iterator(&remaining)
			if strings.trim_space(line) == "---" {
				metadata = text[metadata_start:line_start]
				body = strings.trim_left(remaining, "\r\n")
				break
			}
		}
	}
	note := NoteFile {
		name = strings.clone(name, allocator),
		path = strings.clone(path, allocator),
	}
	remaining = metadata
	for line in strings.split_lines_iterator(&remaining) {
		colon := strings.index_byte(line, ':')
		if colon < 0 do continue
		key := strings.trim_space(line[:colon])
		value := strings.trim_space(line[colon + 1:])
		field: ^string
		switch key {
		case "title":
			field = &note.title
		case "slug":
			field = &note.slug
		case "description":
			field = &note.description
		case:
			continue
		}
		delete(field^, allocator)
		field^ = frontmatter_scalar(value, allocator)
	}

	// Keep explicit front matter, deriving missing preview fields from the body.
	title, description := note_preview(body)
	base := name[:len(name) - len(os.ext(name))]
	if strings.trim_space(body) == "" && !strings.has_prefix(base, "Untitled-") do title = base
	if note.title == "" do note.title = strings.clone(title, allocator)
	if note.description == "" do note.description = strings.clone(description, allocator)
	if note.slug == "" do note.slug = strings.clone(base, allocator)
	note.content = make([]u8, len(body), allocator)
	copy(note.content, transmute([]u8)body)
	return note
}

frontmatter_scalar :: proc(value: string, allocator := context.allocator) -> string {
	if len(value) >= 2 && value[0] == '"' && value[len(value) - 1] == '"' {
		decoded: string
		if json.unmarshal_string(value, &decoded, allocator = allocator) == nil do return decoded
		delete(decoded, allocator)
	}
	if len(value) >= 2 && value[0] == '\'' && value[len(value) - 1] == '\'' {
		decoded, _ := strings.replace_all(value[1:len(value) - 1], "''", "'", allocator)
		return decoded
	}
	return strings.clone(value, allocator)
}
