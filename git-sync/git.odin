package git_sync

import "core:c"

when ODIN_OS == .Windows {
    foreign import native {
        "native/sync.lib", "native/lib/git2.lib",
        "system:winhttp.lib", "system:crypt32.lib", "system:rpcrt4.lib",
        "system:ole32.lib", "system:secur32.lib", "system:bcrypt.lib",
        "system:advapi32.lib", "system:ws2_32.lib", "system:user32.lib",
    }
} else when ODIN_OS == .Linux {
    foreign import native {
        "native/sync.a", "native/lib/libgit2.a",
        "system:ssl", "system:crypto", "system:z", "system:curl",
        "system:secret-1", "system:gio-2.0", "system:gobject-2.0",
        "system:glib-2.0", "system:pthread", "system:dl",
    }
}

@(default_calling_convention = "c")
foreign native {
    dn_native_init :: proc() -> c.int ---
    dn_native_shutdown :: proc() ---
    dn_token_store :: proc(app, token: cstring, error: [^]u8, cap: c.size_t) -> c.int ---
    dn_token_load :: proc(app: cstring, token: [^]u8, cap: c.size_t, error: [^]u8, error_cap: c.size_t) -> c.int ---
    dn_http :: proc(method, url, token, body: cstring, out: [^]u8, cap: c.size_t, status: ^c.int, error: [^]u8, error_cap: c.size_t) -> c.int ---
    dn_sync :: proc(path, url, branch, token, name, email: cstring, error: [^]u8, cap: c.size_t) -> c.int ---
}
