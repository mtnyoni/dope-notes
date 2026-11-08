package markdown

import "core:encoding/json"
import "core:os"
import "core:strings"


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

	// Plain Markdown files do not require front matter.
	remaining = body
	for raw_line in strings.split_lines_iterator(&remaining) {
		line := strings.trim_space(raw_line)
		if strings.has_prefix(line, "# ") {
			if note.title == "" do note.title = strings.clone(strings.trim_space(line[2:]), allocator)
			continue
		}
		if len(line) == 0 || strings.has_prefix(line, "#") do continue
		if note.description == "" do note.description = strings.clone(line, allocator)
		break
	}
	base := name[:len(name) - len(os.ext(name))]
	if note.title == "" do note.title = strings.clone(base, allocator)
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
