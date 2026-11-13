package markdown

import "core:os"
import "core:fmt"
import "core:strings"

// Move legacy loose notes without rewriting their contents or overwriting files.
migrate_note_folders :: proc(notebooks: []Notebook) -> os.Error {
	for &notebook in notebooks {
		for &note in notebook.notes {
			if os.dir(note.path) != notebook.path do continue
			base := note.name[:len(note.name)-len(os.ext(note.name))]
			directory := fmt.tprintf("%s/%s", notebook.path, base)
			index := 1
			for os.exists(directory) {
				directory = fmt.tprintf("%s/%s-%d", notebook.path, base, index)
				index += 1
			}
			if err := os.make_directory_all(fmt.tprintf("%s/attachments", directory)); err != nil do return err
			path := fmt.tprintf("%s/%s", directory, note.name)
			if err := os.rename(note.path, path); err != nil do return err
			delete(note.path)
			note.path = strings.clone(path)
		}
	}
	return nil
}
