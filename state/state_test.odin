package state

import markdown "../markdown"
import "core:testing"

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
