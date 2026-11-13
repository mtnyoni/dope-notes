package markdown

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

@(test)
legacy_notes_migrate_without_loss_and_reload_from_folders :: proc(t: ^testing.T) {
	root, err := os.make_directory_temp("", "dope-storage-*", context.allocator)
	assert(err == nil)
	defer delete(root)
	defer os.remove_all(root)
	notebook := fmt.tprintf("%s/Default", root)
	assert(os.make_directory(notebook) == nil)
	original := "---\ntitle: Test\n---\n\n# Title\n\nBody\n"
	path := fmt.tprintf("%s/Test.md", notebook)
	assert(os.write_entire_file(path, original) == nil)
	// A preexisting directory must never be overwritten by migration.
	assert(os.make_directory(fmt.tprintf("%s/Test", notebook)) == nil)
	notes, load_err := get_notes(root)
	assert(load_err == nil)
	defer free_notebooks(notes)
	testing.expect(t, migrate_note_folders(notes[:]) == nil)
	moved := notes[0].notes[0].path
	testing.expect(t, strings.has_suffix(moved, "/Test-1/Test.md"))
	testing.expect(t, os.is_directory(fmt.tprintf("%s/attachments", os.dir(moved))))
	bytes, read_err := os.read_entire_file(moved, context.allocator)
	assert(read_err == nil)
	defer delete(bytes)
	testing.expect_value(t, string(bytes), original)
	testing.expect(t, !os.exists(path))
	testing.expect(t, migrate_note_folders(notes[:]) == nil)
	reloaded, reload_err := get_notes(root)
	assert(reload_err == nil)
	defer free_notebooks(reloaded)
	testing.expect_value(t, len(reloaded[0].notes), 1)
	testing.expect_value(t, reloaded[0].notes[0].path, moved)
}
