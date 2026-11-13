package state

import markdown "../markdown"
import "core:fmt"
import "core:os"
import "core:strings"

// Notebook and note IDs are file paths, so names can repeat across notebooks.
// Owns the collection loaded by markdown.get_notes at startup. Release
// app.notebooks with markdown.free_notebooks when shutting down.
AppState :: struct {
	notebooks: [dynamic]markdown.Notebook,
	current_notebook: string,
	current_doc: string,
	new_note_requested: bool,
}

create_note :: proc(app: ^AppState) -> os.Error {
	notebook := current_notebook(app)
	if notebook == nil do return nil
	index := 1
	name, path: string
	for {
		name = fmt.tprintf("Untitled-%d.md", index)
		path = fmt.tprintf("%s/Untitled-%d/%s", notebook.path, index, name)
		if !os.exists(fmt.tprintf("%s/Untitled-%d", notebook.path, index)) && !os.exists(fmt.tprintf("%s/%s", notebook.path, name)) do break
		index += 1
	}
	if err := os.make_directory_all(fmt.tprintf("%s/attachments", os.dir(path))); err != nil do return err
	if err := os.write_entire_file(path, ""); err != nil do return err
	note := markdown.parse_note_file(name, path, nil)
	append(&notebook.notes, note)
	app.current_doc = note.path
	return nil
}

update_note_content :: proc(app: ^AppState, path, text: string) {
	for &notebook in app.notebooks {
		for &note in notebook.notes {
			if note.path != path do continue
			if string(note.content) == text do return
			delete(note.content)
			note.content = make([]u8, len(text))
			copy(note.content, transmute([]u8)text)
			title, description := markdown.note_preview(text)
			delete(note.title)
			delete(note.description)
			note.title = strings.clone(title)
			note.description = strings.clone(description)
			return
		}
	}
}

make_app_state :: proc(notebooks: [dynamic]markdown.Notebook, preferred_notebook: string = "business planning") -> AppState {
	app := AppState{notebooks = notebooks}
	if len(notebooks) == 0 do return app
	selected := 0
	for notebook, index in notebooks {
		if notebook.name == preferred_notebook {
			selected = index
			break
		}
	}
	select_notebook(&app, notebooks[selected].path)
	return app
}

select_notebook :: proc(app: ^AppState, path: string) -> bool {
	for notebook in app.notebooks {
		if notebook.path != path do continue
		app.current_notebook = notebook.path
		app.current_doc = ""
		if len(notebook.notes) > 0 do app.current_doc = notebook.notes[0].path
		return true
	}
	return false
}

current_notebook :: proc(app: ^AppState) -> ^markdown.Notebook {
	for &notebook in app.notebooks {
		if notebook.path == app.current_notebook do return &notebook
	}
	return nil
}

current_note :: proc(app: ^AppState) -> ^markdown.NoteFile {
	notebook := current_notebook(app)
	if notebook == nil do return nil
	for &note in notebook.notes {
		if note.path == app.current_doc do return &note
	}
	return nil
}
