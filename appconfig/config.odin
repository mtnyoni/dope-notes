package appconfig

import "core:fmt"

// Direct source builds are isolated by default. Release packaging opts out.
DEVELOPMENT :: #config(DOPE_NOTES_DEV, true)
VERSION_FILE :: #load("../VERSION", string)
DEFAULT_VERSION :: VERSION_FILE[:len(VERSION_FILE) - 1]
VERSION :: #config(DOPE_NOTES_VERSION, DEFAULT_VERSION)
when DEVELOPMENT {
	DISPLAY_VERSION :: VERSION + " (dev)"
	WINDOW_TITLE :: "Dope Notes (Development)"
	APPLICATION_ID :: "com.mtnyoni.dope-notes.dev"
} else {
	DISPLAY_VERSION :: VERSION
	WINDOW_TITLE :: "Dope Notes"
	APPLICATION_ID :: "com.mtnyoni.dope-notes"
}

notebooks_path :: proc(data_home: string, development := DEVELOPMENT) -> string {
	directory := development ? "dope-notes-dev" : "dope-notes"
	return fmt.tprintf("%s/%s/notebooks", data_home, directory)
}
