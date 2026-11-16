package appconfig

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

GITHUB_CLIENT_ID :: #config(DOPE_NOTES_GITHUB_CLIENT_ID, "")

GithubSettings :: struct {
    repository: string,
    branch: string,
    author_name: string,
    author_email: string,
}

github_client_id :: proc() -> string {
    value := os.get_env("DOPE_NOTES_GITHUB_CLIENT_ID", context.temp_allocator)
    return value != "" ? value : GITHUB_CLIENT_ID
}

github_settings_directory :: proc() -> string {
    base := os.get_env("XDG_CONFIG_HOME", context.temp_allocator)
    when ODIN_OS == .Windows {base = os.get_env("APPDATA", context.temp_allocator)}
    if base == "" {
        home := os.get_env("HOME", context.temp_allocator)
        when ODIN_OS == .Windows {home = os.get_env("USERPROFILE", context.temp_allocator)}
        if home == "" {return ""}
        when ODIN_OS == .Windows {base = fmt.tprintf("%s/AppData/Roaming", home)}
        else {base = fmt.tprintf("%s/.config", home)}
    }
    return fmt.tprintf("%s/%s", base, APPLICATION_ID)
}

load_github_settings :: proc() -> (GithubSettings, bool) {
    directory := github_settings_directory()
    if directory == "" {return {}, false}
    data, err := os.read_entire_file(fmt.tprintf("%s/github.json", directory), context.temp_allocator)
    if err != nil {return {}, false}
    saved: GithubSettings
    if json.unmarshal(data, &saved, allocator = context.temp_allocator) != nil {return {}, false}
    return saved, valid_github_repository(saved.repository) && saved.branch != ""
}

save_github_settings :: proc(saved: GithubSettings) -> (bool, string) {
    return write_github_settings(github_settings_directory(), saved)
}

write_github_settings :: proc(directory: string, saved: GithubSettings) -> (bool, string) {
    if directory == "" {return false, "Cannot find the application settings directory"}
    mkdir_err := os.make_directory_all(directory)
    if mkdir_err != nil && mkdir_err != .Exist {
        return false, fmt.tprintf("Cannot create settings directory: %v", mkdir_err)
    }
    data, err := json.marshal(saved, allocator = context.temp_allocator)
    if err != nil {return false, fmt.tprintf("Cannot encode repository settings: %v", err)}
    write_err := os.write_entire_file(fmt.tprintf("%s/github.json", directory), data)
    if write_err != nil {return false, fmt.tprintf("Cannot save repository settings: %v", write_err)}
    return true, ""
}

github_repo :: proc() -> string {
    saved, ok := load_github_settings()
    return ok ? saved.repository : ""
}

valid_github_repository :: proc(value: string) -> bool {
    if strings.count(value, "/") != 1 || len(value) > 150 {return false}
    parts := strings.split(value, "/", context.temp_allocator)
    for part in parts {
        if part == "" || part == "." || part == ".." {return false}
        for ch in part {
            if !(ch >= 'a' && ch <= 'z' || ch >= 'A' && ch <= 'Z' ||
                 ch >= '0' && ch <= '9' || ch == '-' || ch == '_' || ch == '.') {return false}
        }
    }
    return true
}
