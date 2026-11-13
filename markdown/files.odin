package markdown

import "core:os"
import "core:slice"
import "core:strings"

Notebook :: struct {
	name:  string,
	path:  string,
	notes: [dynamic]NoteFile,
}

NoteFile :: struct {
	name:    string, // Filename, including the extension.
	title:   string, // Front matter title, first heading, or filename.
	slug: string,
	description: string,
	path:    string,
	content: []u8,
}

get_notes :: proc(
	directory: string = "markdown/files",
	allocator := context.allocator,
) -> (
	notebooks: [dynamic]Notebook,
	err: os.Error,
) {
	entries, read_err := os.read_all_directory_by_path(directory, allocator)
	if read_err != nil do return nil, read_err
	defer os.file_info_slice_delete(entries, allocator)
	slice.sort_by(entries, proc(a, b: os.File_Info) -> bool {
		return a.name < b.name
	})

	notebooks = make([dynamic]Notebook, allocator)
	defer if err != nil {
		free_notebooks(notebooks, allocator)
		notebooks = nil
	}

	for entry in entries {
		if entry.type != .Directory do continue
		append(
			&notebooks,
			Notebook {
				name = strings.clone(entry.name, allocator),
				path = strings.clone(entry.fullpath, allocator),
				notes = make([dynamic]NoteFile, allocator),
			},
		)

		notebook := &notebooks[len(notebooks) - 1]
		files, file_err := os.read_all_directory_by_path(entry.fullpath, allocator)
		if file_err != nil do return notebooks, file_err
		defer os.file_info_slice_delete(files, allocator)
		slice.sort_by(files, file_name_less)
		for file in files {
			if file.type == .Directory {
				if strings.has_prefix(file.name, ".") do continue
				children, child_err := os.read_all_directory_by_path(file.fullpath, allocator)
				if child_err != nil do return notebooks, child_err
				for child in children {
					if child.type != .Regular do continue
					ext := os.ext(child.name)
					if !strings.equal_fold(ext, ".md") && !strings.equal_fold(ext, ".markdown") do continue
					bytes, err := os.read_entire_file(child.fullpath, allocator)
					if err != nil { os.file_info_slice_delete(children, allocator); return notebooks, err }
					append(&notebook.notes, parse_note_file(child.name, child.fullpath, bytes, allocator))
					delete(bytes, allocator)
				}
				os.file_info_slice_delete(children, allocator)
				continue
			}
			if file.type != .Regular do continue
			extension := os.ext(file.name)
			if !strings.equal_fold(extension, ".md") && !strings.equal_fold(extension, ".markdown") do continue
			content, content_err := os.read_entire_file(file.fullpath, allocator)
			if content_err != nil do return notebooks, content_err
			note := parse_note_file(file.name, file.fullpath, content, allocator)
			delete(content, allocator)
			append(&notebook.notes, note)
		}
	}

	return notebooks, nil
}

free_notebooks :: proc(notebooks: [dynamic]Notebook, allocator := context.allocator) {
	for notebook in notebooks {
		for note in notebook.notes {
			delete(note.name, allocator)
			delete(note.title, allocator)
			delete(note.slug, allocator)
			delete(note.description, allocator)
			delete(note.path, allocator)
			delete(note.content, allocator)
		}
		delete(notebook.notes)
		delete(notebook.name, allocator)
		delete(notebook.path, allocator)
	}
	delete(notebooks)
}

file_name_less :: proc(a, b: os.File_Info) -> bool {
	return a.name < b.name
}
