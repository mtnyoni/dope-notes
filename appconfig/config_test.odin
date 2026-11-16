package appconfig

import "core:testing"
import "core:os"
import "core:fmt"
import "core:encoding/json"

@(test)
development_and_production_use_separate_notebooks :: proc(t: ^testing.T) {
	testing.expect_value(t, notebooks_path("/tmp/data", true), "/tmp/data/dope-notes-dev/notebooks")
	testing.expect_value(t, notebooks_path("/tmp/data", false), "/tmp/data/dope-notes/notebooks")
	testing.expect_value(t, notebooks_path("/tmp/data"), DEVELOPMENT ? "/tmp/data/dope-notes-dev/notebooks" : "/tmp/data/dope-notes/notebooks")
}

@(test)
github_repository_rejects_urls_and_path_traversal :: proc(t: ^testing.T) {
    valid := [3]string{"mtnyoni/dope-notes-sync", "some-user/notes.v2", "team/notes_private"}
    for value in valid {testing.expect(t, valid_github_repository(value))}
    invalid := [9]string{"", "owner", "/notes", "owner/", "../notes", "owner/..", "owner/a/b", "https://github.com/owner/notes", "owner/notes?token=secret"}
    for value in invalid {testing.expect(t, !valid_github_repository(value))}
}

@(test)
github_settings_save_into_existing_directory :: proc(t: ^testing.T) {
    directory := fmt.tprintf("/tmp/dope-github-settings-%d", os.get_pid())
    defer os.remove_all(directory)
    settings := GithubSettings{
        repository = "example/notes", branch = "main",
        author_name = "Example", author_email = "example@example.invalid",
    }
    ok, error := write_github_settings(directory, settings)
    testing.expect(t, ok, error)
    settings.branch = "notes"
    ok, error = write_github_settings(directory, settings)
    testing.expect(t, ok, error)
    data, read_err := os.read_entire_file(fmt.tprintf("%s/github.json", directory), context.temp_allocator)
    testing.expect(t, read_err == nil)
    actual: GithubSettings
    testing.expect(t, json.unmarshal(data, &actual, allocator = context.temp_allocator) == nil)
    testing.expect_value(t, actual.branch, "notes")
}
