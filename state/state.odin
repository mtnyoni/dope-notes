package state

import markdown "../markdown"

// Notebook and note IDs are file paths, so names can repeat across notebooks.
// Owns the collection loaded by markdown.get_notes at startup. Release
// app.notebooks with markdown.free_notebooks when shutting down.
AppState :: struct {
	notebooks: [dynamic]markdown.Notebook,
	current_notebook: string,
	current_doc: string,
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
