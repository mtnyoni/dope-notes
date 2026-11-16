package appconfig

import "core:os"
import "core:strings"

// Repository is configured as owner/name. No token is stored by the app.
github_repo :: proc() -> string {
	return strings.trim_space(os.get_env("DOPE_NOTES_GITHUB_REPO", context.temp_allocator))
}

