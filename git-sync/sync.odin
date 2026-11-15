package git_sync

import "core:c"
import "core:fmt"

when ODIN_OS == .Windows {
	foreign import git2 "system:git2.lib"
} else when ODIN_PLATFORM_SUBTARGET == .Android {
	foreign import git2 {"libs/android/arm64-v8a/libgit2.a", "libs/android/arm64-v8a/libmbedtls.a", "libs/android/arm64-v8a/libmbedx509.a", "libs/android/arm64-v8a/libmbedcrypto.a", "system:z"}
} else {
	foreign import git2 "system:git2"
}

Repository :: struct {} // opaque type

@(default_calling_convention = "c", link_prefix = "git_")
foreign git2 {
	libgit2_init :: proc() -> c.int ---
	libgit2_shutdown :: proc() -> c.int ---
	clone :: proc(out: ^^Repository, url, local_path: cstring, options: rawptr) -> c.int ---
	repository_free :: proc(repo: ^Repository) ---
}

setup_sync :: proc() {
	libgit2_init()
	defer libgit2_shutdown()

	repo: ^Repository
	err := clone(&repo, "https://github.com/you/your-repo.git", "local_dir", nil)
	if err != 0 {
		fmt.println("clone failed:", err)
		return
	}
	defer repository_free(repo)
	fmt.println("cloned")
}
