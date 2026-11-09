package appconfig

import "core:fmt"
import "core:os"
import "core:strings"

// Repository is configured as owner/name. No token is stored by the app.
github_repo :: proc() -> string {
	return strings.trim_space(os.get_env("DOPE_NOTES_GITHUB_REPO", context.temp_allocator))
}

run_sync_command :: proc(directory: string, command: []string) -> bool {
	state, stdout, stderr, err := os.process_exec({working_dir = directory, command = command}, context.temp_allocator)
	if err != nil {
		fmt.eprintln("GitHub sync command failed:", command, err)
		return false
	}
	if state.exit_code != 0 {
		fmt.eprintln("GitHub sync command failed:", command, string(stderr), string(stdout))
		return false
	}
	return true
}

sync_github :: proc(notes_dir: string) -> bool {
	repo := github_repo()
	if repo == "" || strings.count(repo, "/") != 1 {
		fmt.eprintln("Set DOPE_NOTES_GITHUB_REPO=owner/repo to enable GitHub sync")
		return false
	}
	if !run_sync_command(notes_dir, {"gh", "auth", "status"}) do return false
	if !run_sync_command(notes_dir, {"gh", "repo", "view", repo, "--json", "nameWithOwner"}) do return false
	if !os.exists(fmt.tprintf("%s/.git", notes_dir)) {
		if !run_sync_command(notes_dir, {"git", "init"}) do return false
		if !run_sync_command(notes_dir, {"git", "branch", "-M", "main"}) do return false
		if !run_sync_command(notes_dir, {"git", "remote", "add", "origin", fmt.tprintf("https://github.com/%s.git", repo)}) do return false
	}
	remote_state, remote_url, _, remote_err := os.process_exec({working_dir = notes_dir, command = {"git", "remote", "get-url", "origin"}}, context.temp_allocator)
	if remote_err != nil || remote_state.exit_code != 0 || strings.trim_space(string(remote_url)) != fmt.tprintf("https://github.com/%s.git", repo) {
		fmt.eprintln("Notes directory origin does not match DOPE_NOTES_GITHUB_REPO")
		return false
	}
	// GitHub CLI supplies Git's credentials through the active login.
	if !run_sync_command(notes_dir, {"gh", "auth", "setup-git"}) do return false
	if !run_sync_command(notes_dir, {"git", "add", "--", "."}) do return false
	// An empty commit is harmless and allows first sync of a new notes directory.
	if !run_sync_command(notes_dir, {"git", "commit", "--allow-empty", "-m", "Sync notes"}) do return false
	branch_state, remote_output, remote_error, branch_err := os.process_exec({working_dir = notes_dir, command = {"git", "ls-remote", "--heads", "origin", "main"}}, context.temp_allocator)
	if branch_err != nil || branch_state.exit_code != 0 {
		fmt.eprintln("Could not inspect remote branch:", branch_err, string(remote_error))
		return false
	}
	if len(remote_output) > 0 {
		if !run_sync_command(notes_dir, {"git", "fetch", "origin", "main"}) do return false
		if !run_sync_command(notes_dir, {"git", "rebase", "origin/main"}) do return false
	}
	return run_sync_command(notes_dir, {"git", "push", "-u", "origin", "main"})
}
