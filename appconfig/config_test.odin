package appconfig

import "core:testing"

@(test)
development_and_production_use_separate_notebooks :: proc(t: ^testing.T) {
	testing.expect_value(t, notebooks_path("/tmp/data", true), "/tmp/data/dope-notes-dev/notebooks")
	testing.expect_value(t, notebooks_path("/tmp/data", false), "/tmp/data/dope-notes/notebooks")
	testing.expect_value(t, notebooks_path("/tmp/data"), DEVELOPMENT ? "/tmp/data/dope-notes-dev/notebooks" : "/tmp/data/dope-notes/notebooks")
}
