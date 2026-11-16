package git_sync

import config "../appconfig"
import ui "../ui"
import "base:runtime"
import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import sdl "vendor:sdl3"

cstr :: proc(value: string) -> cstring {
    return strings.clone_to_cstring(value, context.temp_allocator)
}

native_init :: proc() -> bool {return dn_native_init() == 0}
native_shutdown :: proc() {dn_native_shutdown()}

http_json :: proc(method, url, token, body: string) -> (string, int, string) {
    output := make([]u8, 256 * 1024, context.temp_allocator)
    error: [1024]u8
    status: c.int
    result := dn_http(cstr(method), cstr(url), cstr(token), cstr(body),
        raw_data(output), c.size_t(len(output)), &status, &error[0], len(error))
    if result != 0 {
        fmt.eprintfln("GitHub HTTP %s %s: %s", method, url, string(cstring(&error[0])))
        return "", 0, strings.clone(string(cstring(&error[0])), context.temp_allocator)
    }
    if status >= 400 {fmt.eprintfln("GitHub HTTP %s %s: status %d", method, url, status)}
    return string(cstring(raw_data(output))), int(status), ""
}

load_token :: proc() -> (string, string) {
    token: [2048]u8
    error: [1024]u8
    result := dn_token_load(cstr(config.APPLICATION_ID), &token[0], len(token), &error[0], len(error))
    defer for &byte in token {byte = 0}
    if result == 1 {return "", "Sign in to GitHub to sync your notes"}
    if result != 0 {return "", strings.clone(string(cstring(&error[0])), context.temp_allocator)}
    return strings.clone(string(cstring(&token[0])), context.temp_allocator), ""
}

AuthJob :: enum {None, Begin, Poll, Connect, Create, Reset}
AuthWorker :: struct {
    mutex: ^sdl.Mutex,
    thread: ^sdl.Thread,
    job: AuthJob,
    done: bool,
    success: bool,
    pending: bool,
    interval: int,
    next_poll: u64,
    expires: u64,
    client_id: [200]u8,
    device_code: [256]u8,
    user_code: [32]u8,
    repository: [160]u8,
    branch: [80]u8,
    error: [1024]u8,
}

copy_text :: proc(out: []u8, value: string) {
    for &byte in out {byte = 0}
    copy(out[:max(0, len(out)-1)], transmute([]u8)value)
}

GithubDeviceResponse :: struct {
    device_code: string,
    user_code: string,
    verification_uri: string,
    expires_in: int,
    interval: int,
    access_token: string,
    error: string,
    error_description: string,
}
GithubUser :: struct {login: string, id: i64, name: string}
GithubRepository :: struct {
    full_name: string,
    private: bool,
    permissions: struct {push: bool},
    message: string,
}

auth_thread :: proc "c" (data: rawptr) -> c.int {
    context = runtime.default_context()
    worker := cast(^AuthWorker)data
    error := ""
    success, pending := false, false
    #partial switch worker.job {
    case .Reset:
        native_error: [1024]u8
        if dn_token_delete(cstr(config.APPLICATION_ID), &native_error[0], len(native_error)) != 0 {
            error = string(cstring(&native_error[0]))
        } else {
            directory := config.github_settings_directory()
            if directory == "" {error = "Cannot find repository settings"}
            else {
                remove_error := os.remove(fmt.tprintf("%s/github.json", directory))
                success = remove_error == nil || remove_error == .Not_Exist
                if !success {error = fmt.tprintf("Cannot remove repository settings: %v", remove_error)}
            }
        }
    case .Begin:
        body, _ := json.marshal(struct {client_id: string, scope: string}{string(cstring(&worker.client_id[0])), "repo"}, allocator = context.temp_allocator)
        response, status, http_error := http_json("POST", "https://github.com/login/device/code", "", string(body))
        decoded: GithubDeviceResponse
        if http_error != "" {error = "Cannot reach GitHub. Check your connection."}
        else if status != 200 || json.unmarshal(transmute([]u8)response, &decoded, allocator = context.temp_allocator) != nil {error = "Could not start GitHub sign-in"}
        else if decoded.error != "" {error = decoded.error_description}
        else if decoded.device_code == "" || decoded.user_code == "" {error = "GitHub returned an invalid sign-in code"}
        else {
            copy_text(worker.device_code[:], decoded.device_code)
            copy_text(worker.user_code[:], decoded.user_code)
            worker.interval = max(5, decoded.interval)
            worker.expires = sdl.GetTicksNS() + u64(max(1, decoded.expires_in)) * 1_000_000_000
            success = true
        }
    case .Poll:
        body, _ := json.marshal(struct {client_id, device_code, grant_type: string}{string(cstring(&worker.client_id[0])), string(cstring(&worker.device_code[0])), "urn:ietf:params:oauth:grant-type:device_code"}, allocator = context.temp_allocator)
        response, status, http_error := http_json("POST", "https://github.com/login/oauth/access_token", "", string(body))
        decoded: GithubDeviceResponse
        if http_error != "" {error = "Cannot reach GitHub. Sign in again when connected."}
        else if status != 200 || json.unmarshal(transmute([]u8)response, &decoded, allocator = context.temp_allocator) != nil {error = "Could not complete GitHub sign-in"}
        else if decoded.error == "authorization_pending" {pending = true}
        else if decoded.error == "slow_down" {worker.interval += 5; pending = true}
        else if decoded.error != "" {error = "GitHub sign-in was denied or expired. Please try again."}
        else if decoded.access_token == "" {error = "GitHub did not return an access token"}
        else {
            native_error: [1024]u8
            success = dn_token_store(cstr(config.APPLICATION_ID), cstr(decoded.access_token), &native_error[0], len(native_error)) == 0
            if !success {error = string(cstring(&native_error[0]))}
        }
    case .Connect, .Create:
        token, token_error := load_token()
        if token == "" {error = token_error; break}
        repository := string(cstring(&worker.repository[0]))
        branch := string(cstring(&worker.branch[0]))
        if !config.valid_github_repository(repository) || branch == "" {error = "Enter owner/repository and a branch"; break}
        user_json, user_status, network_error := http_json("GET", "https://api.github.com/user", token, "")
        user: GithubUser
        if network_error != "" {error = "Cannot reach GitHub. Check your connection."; break}
        if user_status != 200 || json.unmarshal(transmute([]u8)user_json, &user, allocator = context.temp_allocator) != nil {error = "GitHub session expired. Sign in again."; break}
        if worker.job == .Create {
            parts := strings.split(repository, "/", context.temp_allocator)
            if parts[0] != user.login {error = "Create the repository under your signed-in GitHub account"; break}
            body, _ := json.marshal(struct {name: string, private: bool, auto_init: bool}{parts[1], true, false}, allocator = context.temp_allocator)
            _, status, request_error := http_json("POST", "https://api.github.com/user/repos", token, string(body))
            if request_error != "" || status != 201 {error = "Could not create repository. If it exists, use Connect repository."; break}
        }
        repo_json, repo_status, repo_error := http_json("GET", fmt.tprintf("https://api.github.com/repos/%s", repository), token, "")
        repo: GithubRepository
        if repo_error != "" {error = "Cannot reach GitHub. Check your connection."; break}
        if repo_status == 404 {
            if strings.has_prefix(token, "ghu_") {
                error = "This GitHub App needs to be installed on the notes repository with Contents read/write permission. Alternatively, use an OAuth App Client ID."
            } else {
                error = fmt.tprintf("GitHub account %s cannot access %s (404). Check the repository name and OAuth app access to this private repo.", user.login, repository)
            }
            break
        }
        if repo_status != 200 || json.unmarshal(transmute([]u8)repo_json, &repo, allocator = context.temp_allocator) != nil {error = fmt.tprintf("Cannot open repository (HTTP %d)", repo_status); break}
        if !repo.permissions.push {error = "Your account needs write access to this repository"; break}
        if !repo.private {error = "Choose a private repository to keep your notes private"; break}
        saved := config.GithubSettings{
            repository = repository, branch = branch,
            author_name = user.name != "" ? user.name : user.login,
            author_email = fmt.tprintf("%d+%s@users.noreply.github.com", user.id, user.login),
        }
        success, error = config.save_github_settings(saved)
    }
    if !success && !pending {fmt.eprintfln("GitHub setup [%v]: %s", worker.job, error)}
    copy_text(worker.error[:], error)
    sdl.LockMutex(worker.mutex)
    worker.success = success
    worker.pending = pending
    worker.done = true
    sdl.UnlockMutex(worker.mutex)
    free_all(context.temp_allocator)
    return 0
}

start_auth_job :: proc(worker: ^AuthWorker, job: AuthJob) -> bool {
    worker.job = job
    worker.done = false
    worker.thread = sdl.CreateThread(auth_thread, "github-sign-in", worker)
    if worker.thread == nil {
        copy_text(worker.error[:], "Could not start GitHub sign-in")
        worker.done = true
        return false
    }
    return true
}

update_github_setup :: proc(worker: ^AuthWorker, setup: ^ui.GithubSetupState, sync_pending: ^bool, allow_reset := true) {
    if worker.thread != nil {
        sdl.LockMutex(worker.mutex)
        done := worker.done
        sdl.UnlockMutex(worker.mutex)
        if done {
            sdl.WaitThread(worker.thread, nil)
            worker.thread = nil
            if worker.pending {
                worker.next_poll = sdl.GetTicksNS() + u64(worker.interval) * 1_000_000_000
            } else if worker.success {
                #partial switch worker.job {
                case .Reset:
                    setup^ = ui.GithubSetupState{open = true, just_opened = true}
                    sync_pending^ = false
                    worker.device_code = {}
                    worker.user_code = {}
                case .Begin:
                    copy_text(setup.user_code[:], string(cstring(&worker.user_code[0])))
                    setup.phase = .Authorizing
                    worker.next_poll = sdl.GetTicksNS() + u64(worker.interval) * 1_000_000_000
                    _ = sdl.OpenURL("https://github.com/login/device")
                case .Poll:
                    setup.phase = .Repository
                case .Connect, .Create:
                    setup.open = false
                    sync_pending^ = true
                }
            } else {
                if worker.job == .Reset {setup.reset_requested = false; setup.open = true}
                copy_text(setup.error[:], string(cstring(&worker.error[0])))
                setup.phase = worker.job == .Connect || worker.job == .Create ? .Repository : .Welcome
            }
        }
    }
    if worker.thread != nil {return}
    if setup.reset_requested {
        if !allow_reset {return}
        setup.open = true
        setup.just_opened = true
        setup.phase = .Busy
        setup.request = .None
        if !start_auth_job(worker, .Reset) {
            setup.reset_requested = false
            setup.phase = .Welcome
            copy_text(setup.error[:], "Could not reset GitHub connection")
        }
        return
    }
    if !setup.open {return}
    if setup.request != .None {
        request := setup.request
        setup.request = .None
        copy_text(setup.error[:], "")
        if request == .SignIn {
            client := config.github_client_id()
            if client == "" {
                copy_text(setup.error[:], "GitHub sign-in is not configured. Set the app Client ID.")
                return
            }
            copy_text(worker.client_id[:], client)
            setup.phase = .Busy
            if !start_auth_job(worker, .Begin) {setup.phase = .Welcome; copy_text(setup.error[:], "Could not start sign-in")}
        } else {
            copy_text(worker.repository[:], string(setup.repository[:setup.repository_length]))
            copy_text(worker.branch[:], string(setup.branch[:setup.branch_length]))
            setup.phase = .Busy
            if !start_auth_job(worker, request == .Create ? .Create : .Connect) {setup.phase = .Repository; copy_text(setup.error[:], "Could not connect repository")}
        }
    } else if setup.phase == .Authorizing && sdl.GetTicksNS() >= worker.next_poll {
        if sdl.GetTicksNS() >= worker.expires {
            setup.phase = .Welcome
            copy_text(setup.error[:], "Sign-in expired. Please sign in again.")
        } else if !start_auth_job(worker, .Poll) {setup.phase = .Welcome; copy_text(setup.error[:], "Could not check authorization")}
    }
}
