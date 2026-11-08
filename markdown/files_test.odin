package markdown

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

@(test)
loads_notebook_folders_and_note_frontmatter :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "dope-notes-notebooks-*", context.allocator)
	assert(err == nil)
	defer {
		_ = os.remove_all(root)
		delete(root)
	}
	business := fmt.tprintf("%s/business planning", root)
	assert(os.make_directory(business) == nil)
	assert(os.make_directory(fmt.tprintf("%s/empty notebook", root)) == nil)
	assert(os.make_directory(fmt.tprintf("%s/nested", business)) == nil)
	assert(os.write_entire_file(fmt.tprintf("%s/root.md", root), "Ignored") == nil)
	assert(os.write_entire_file(fmt.tprintf("%s/a.MD", business), "---\nslug: \"plan\"\ntitle: \"Business Plan\"\ndescription: \"Feedback for cafés.\"\n---\n\n# Business Plan\n\nA plan.") == nil)
	assert(os.write_entire_file(fmt.tprintf("%s/b.markdown", business), "# Plain Note\n\nPlain description.\n") == nil)
	assert(os.write_entire_file(fmt.tprintf("%s/c.md", business), "") == nil)
	assert(os.write_entire_file(fmt.tprintf("%s/image.png", business), "Ignored") == nil)
	assert(os.write_entire_file(fmt.tprintf("%s/nested/ignored.md", business), "Ignored") == nil)
	notebooks, load_err := get_notes(root)
	defer free_notebooks(notebooks)
	testing.expect(t, load_err == nil)
	testing.expect_value(t, len(notebooks), 2)
	if len(notebooks) != 2 do return
	testing.expect_value(t, notebooks[0].name, "business planning")
	testing.expect_value(t, notebooks[1].name, "empty notebook")
	testing.expect_value(t, len(notebooks[1].notes), 0)
	testing.expect_value(t, len(notebooks[0].notes), 3)
	if len(notebooks[0].notes) != 3 do return
	a := notebooks[0].notes[0]
	testing.expect_value(t, a.slug, "plan")
	testing.expect_value(t, a.title, "Business Plan")
	testing.expect_value(t, a.description, "Feedback for cafés.")
	testing.expect_value(t, string(a.content), "# Business Plan\n\nA plan.")
	testing.expect(t, strings.has_suffix(a.path, "a.MD"))
	b := notebooks[0].notes[1]
	testing.expect_value(t, b.title, "Plain Note")
	testing.expect_value(t, b.description, "Plain description.")
	testing.expect_value(t, notebooks[0].notes[2].title, "c")
	testing.expect_value(t, len(notebooks[0].notes[2].content), 0)

	missing, missing_err := get_notes(fmt.tprintf("%s/does-not-exist", root))
	defer free_notebooks(missing)
	testing.expect(t, missing_err != nil)
	testing.expect_value(t, len(missing), 0)
}
