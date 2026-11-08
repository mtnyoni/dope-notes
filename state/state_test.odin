package state

import markdown "../markdown"
import "core:testing"
import "core:os"
import "core:fmt"

@(test)
default_notebook_and_future_notebook_selection :: proc(t: ^testing.T) {
	first_notes := make([dynamic]markdown.NoteFile)
	defer delete(first_notes)
	append(&first_notes, markdown.NoteFile{path = "a/plan.md", slug = "plan"})
	business_notes := make([dynamic]markdown.NoteFile)
	defer delete(business_notes)
	append(&business_notes, markdown.NoteFile{path = "business planning/plan.md", slug = "plan"})
	notebooks := make([dynamic]markdown.Notebook)
	defer delete(notebooks)
	append(&notebooks, markdown.Notebook{name = "another notebook", path = "a", notes = first_notes})
	append(&notebooks, markdown.Notebook{name = "business planning", path = "business planning", notes = business_notes})
	append(&notebooks, markdown.Notebook{name = "empty", path = "empty"})
	app := make_app_state(notebooks)
	testing.expect_value(t, app.current_notebook, "business planning")
	testing.expect_value(t, current_note(&app).path, "business planning/plan.md")
	testing.expect(t, select_notebook(&app, "a"))
	testing.expect_value(t, current_note(&app).path, "a/plan.md")
	testing.expect(t, select_notebook(&app, "empty"))
	testing.expect_value(t, app.current_doc, "")
	testing.expect(t, current_note(&app) == nil)
	testing.expect(t, !select_notebook(&app, "missing"))
	testing.expect_value(t, app.current_notebook, "empty")
	fallback := make_app_state(notebooks, "missing")
	testing.expect_value(t, fallback.current_notebook, "a")
	empty := make_app_state(nil)
	testing.expect(t, current_notebook(&empty) == nil && current_note(&empty) == nil)
}

@(test)
new_notes_are_unique_and_preview_follows_edits :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "dope-new-note-*", context.allocator)
	testing.expect(t, err == nil)
	if err != nil do return
	defer delete(root)
	defer os.remove_all(root)
	assert(os.make_directory(fmt.tprintf("%s/Default", root)) == nil)
	notebooks, load_err := markdown.get_notes(root)
	assert(load_err == nil)
	app := make_app_state(notebooks, "Default")
	defer markdown.free_notebooks(app.notebooks)
	testing.expect(t, create_note(&app) == nil)
	first_path := current_note(&app).path
	testing.expect(t, os.exists(first_path))
	testing.expect_value(t, current_note(&app).title, "Untitled")
	text := "# Shopping\n\nBuy bread\nBuy milk"
	update_note_content(&app, first_path, text)
	testing.expect_value(t, current_note(&app).title, "Shopping")
	testing.expect_value(t, current_note(&app).description, "Buy bread")
	assert(os.write_entire_file(first_path, text) == nil)
	testing.expect(t, create_note(&app) == nil)
	testing.expect(t, current_note(&app).path != first_path)
	testing.expect_value(t, len(current_notebook(&app).notes), 2)
	reloaded, reload_err := markdown.get_notes(root)
	assert(reload_err == nil)
	defer markdown.free_notebooks(reloaded)
	testing.expect_value(t, reloaded[0].notes[0].title, "Shopping")
	testing.expect_value(t, reloaded[0].notes[0].description, "Buy bread")
	testing.expect_value(t, reloaded[0].notes[1].title, "Untitled")
	update_note_content(&app, first_path, "Renamed\nNew description")
	testing.expect_value(t, current_notebook(&app).notes[0].title, "Renamed")
	update_note_content(&app, first_path, "")
	testing.expect_value(t, current_notebook(&app).notes[0].title, "Untitled")
	testing.expect_value(t, current_notebook(&app).notes[0].description, "")
}
