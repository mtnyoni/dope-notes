#include <git2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#ifdef _WIN32
#include <windows.h>
#include <winhttp.h>
#include <wincred.h>
#else
#include <curl/curl.h>
#include <libsecret/secret.h>
#endif

static void message(char *out, size_t n, const char *s) {
    if (n) snprintf(out, n, "%s", s ? s : "Unknown error");
}
static int git_failure(char *out, size_t n, const char *step) {
    const git_error *e = git_error_last();
    snprintf(out, n, "%s: %s", step, e && e->message ? e->message : "Git operation failed");
    return -1;
}
int dn_native_init(void) {
#ifndef _WIN32
    if (curl_global_init(CURL_GLOBAL_DEFAULT)) return -1;
#endif
    if (git_libgit2_init() < 0) return -1;
    git_libgit2_opts(GIT_OPT_SET_SERVER_CONNECT_TIMEOUT, 5000);
    git_libgit2_opts(GIT_OPT_SET_SERVER_TIMEOUT, 20000);
    return 0;
}
void dn_native_shutdown(void) {
    git_libgit2_shutdown();
#ifndef _WIN32
    curl_global_cleanup();
#endif
}

#ifndef _WIN32
static const SecretSchema schema = {
    .name = "com.mtnyoni.dope-notes.github", .flags = SECRET_SCHEMA_NONE,
    .attributes = {{"application", SECRET_SCHEMA_ATTRIBUTE_STRING}, {NULL, 0}}
};
#endif
int dn_token_store(const char *app, const char *token, char *error, size_t cap) {
#ifdef _WIN32
    CREDENTIALA c = {0};
    c.Type = CRED_TYPE_GENERIC; c.TargetName = (char *)app;
    c.CredentialBlob = (LPBYTE)token; c.CredentialBlobSize = (DWORD)strlen(token);
    c.Persist = CRED_PERSIST_LOCAL_MACHINE; c.UserName = "github";
    if (CredWriteA(&c, 0)) return 0;
    message(error, cap, "Windows Credential Manager could not save the session");
#else
    GError *e = NULL;
    if (secret_password_store_sync(&schema, SECRET_COLLECTION_DEFAULT,
        "Dope Notes GitHub", token, NULL, &e, "application", app, NULL)) return 0;
    message(error, cap, e ? e->message : "Keyring could not save the session");
    if (e) g_error_free(e);
#endif
    return -1;
}
int dn_token_load(const char *app, char *token, size_t cap, char *error, size_t error_cap) {
#ifdef _WIN32
    PCREDENTIALA c = NULL;
    if (!CredReadA(app, CRED_TYPE_GENERIC, 0, &c)) {
        if (GetLastError() == ERROR_NOT_FOUND) return 1;
        message(error, error_cap, "Windows Credential Manager is unavailable"); return -1;
    }
    if (c->CredentialBlobSize >= cap) {CredFree(c); return -1;}
    memcpy(token, c->CredentialBlob, c->CredentialBlobSize);
    token[c->CredentialBlobSize] = 0; CredFree(c); return 0;
#else
    GError *e = NULL;
    char *value = secret_password_lookup_sync(&schema, NULL, &e, "application", app, NULL);
    if (!value) {
        if (e) {message(error, error_cap, e->message); g_error_free(e); return -1;}
        return 1;
    }
    if (strlen(value) >= cap) {secret_password_free(value); return -1;}
    message(token, cap, value); secret_password_free(value); return 0;
#endif
}

#ifndef _WIN32
struct response {char *out; size_t cap, len;};
static size_t receive(void *data, size_t size, size_t count, void *payload) {
    struct response *r = payload; size_t n = size * count;
    if (n >= r->cap - r->len) return 0;
    memcpy(r->out + r->len, data, n); r->len += n; r->out[r->len] = 0;
    return n;
}
#endif
/* Only fixed GitHub HTTPS endpoints are accepted. Never follow redirects with credentials. */
int dn_http(const char *method, const char *url, const char *token, const char *body,
    char *out, size_t cap, int *status, char *error, size_t error_cap) {
    if (strncmp(url, "https://github.com/login/", 25) &&
        strncmp(url, "https://api.github.com/", 23)) {
        message(error, error_cap, "Unexpected GitHub endpoint"); return -1;
    }
    out[0] = 0; *status = 0;
#ifdef _WIN32
    wchar_t wide[2048];
    if (!MultiByteToWideChar(CP_UTF8, 0, url, -1, wide, 2048)) return -1;
    URL_COMPONENTS u = {0}; u.dwStructSize = sizeof(u);
    wchar_t host[256], path[1800];
    u.lpszHostName = host; u.dwHostNameLength = 256;
    u.lpszUrlPath = path; u.dwUrlPathLength = 1800;
    if (!WinHttpCrackUrl(wide, 0, 0, &u)) return -1;
    HINTERNET session = WinHttpOpen(L"DopeNotes", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, NULL, NULL, 0);
    if (!session) return -1;
    WinHttpSetTimeouts(session, 5000, 5000, 10000, 15000);
    HINTERNET connection = WinHttpConnect(session, host, u.nPort, 0);
    wchar_t verb[16]; MultiByteToWideChar(CP_UTF8, 0, method, -1, verb, 16);
    HINTERNET request = connection ? WinHttpOpenRequest(connection, verb, path, NULL, NULL, NULL, WINHTTP_FLAG_SECURE) : NULL;
    int result = -1;
    if (request) {
        DWORD policy = WINHTTP_OPTION_REDIRECT_POLICY_NEVER;
        WinHttpSetOption(request, WINHTTP_OPTION_REDIRECT_POLICY, &policy, sizeof(policy));
        WinHttpAddRequestHeaders(request, L"Accept: application/json\r\nContent-Type: application/json", (DWORD)-1, WINHTTP_ADDREQ_FLAG_ADD);
        if (token && *token) {
            char auth[2048]; wchar_t wauth[2048];
            snprintf(auth, sizeof(auth), "Authorization: Bearer %s", token);
            MultiByteToWideChar(CP_UTF8, 0, auth, -1, wauth, 2048);
            WinHttpAddRequestHeaders(request, wauth, (DWORD)-1, WINHTTP_ADDREQ_FLAG_ADD);
        }
        DWORD length = body ? (DWORD)strlen(body) : 0;
        if (WinHttpSendRequest(request, NULL, 0, (void *)body, length, length, 0) && WinHttpReceiveResponse(request, NULL)) {
            DWORD code = 0, size = sizeof(code);
            WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, NULL, &code, &size, NULL);
            *status = (int)code; size_t used = 0; DWORD got;
            result = 0;
            while (WinHttpReadData(request, out + used, (DWORD)(cap - used - 1), &got) && got) {
                used += got;
                if (used + 1 >= cap) {result = -1; break;}
            }
            out[used] = 0;
        }
        WinHttpCloseHandle(request);
    }
    if (connection) WinHttpCloseHandle(connection);
    WinHttpCloseHandle(session);
    if (result) message(error, error_cap, "Cannot reach GitHub. Check your connection.");
    return result;
#else
    CURL *c = curl_easy_init(); if (!c) return -1;
    struct response r = {out, cap, 0}; struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Accept: application/json");
    headers = curl_slist_append(headers, "Content-Type: application/json");
    char auth[2048];
    if (token && *token) {snprintf(auth, sizeof(auth), "Authorization: Bearer %s", token); headers = curl_slist_append(headers, auth);}
    curl_easy_setopt(c, CURLOPT_URL, url);
    curl_easy_setopt(c, CURLOPT_USERAGENT, "DopeNotes");
    curl_easy_setopt(c, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(c, CURLOPT_CUSTOMREQUEST, method);
    if (!strcmp(method, "HEAD")) curl_easy_setopt(c, CURLOPT_NOBODY, 1L);
    curl_easy_setopt(c, CURLOPT_CONNECTTIMEOUT, 5L);
    curl_easy_setopt(c, CURLOPT_TIMEOUT, 20L);
    curl_easy_setopt(c, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(c, CURLOPT_WRITEFUNCTION, receive);
    curl_easy_setopt(c, CURLOPT_WRITEDATA, &r);
    if (body && *body) curl_easy_setopt(c, CURLOPT_POSTFIELDS, body);
    CURLcode code = curl_easy_perform(c); long http = 0;
    curl_easy_getinfo(c, CURLINFO_RESPONSE_CODE, &http); *status = (int)http;
    if (code) message(error, error_cap, curl_easy_strerror(code));
    curl_slist_free_all(headers); curl_easy_cleanup(c);
    return code ? -1 : 0;
#endif
}

struct credentials {const char *token; int attempts; char *error; size_t cap;};
static int credentials(git_credential **out, const char *url, const char *username,
    unsigned allowed, void *payload) {
    (void)username; struct credentials *c = payload;
    if (strncmp(url, "https://github.com/", 19) || ++c->attempts > 1 ||
        !(allowed & GIT_CREDENTIAL_USERPASS_PLAINTEXT)) return GIT_EAUTH;
    return git_credential_userpass_plaintext_new(out, "x-access-token", c->token);
}
static int push_status(const char *ref, const char *status, void *payload) {
    (void)ref; struct credentials *c = payload;
    if (status) {message(c->error, c->cap, status); return -1;}
    return 0;
}
/* Result: 0 synced, 1 no local changes, -1 failure. */
int dn_sync(const char *path, const char *url, const char *branch, const char *token,
    const char *name, const char *email, char *error, size_t cap) {
    git_repository *repo = NULL; git_remote *remote = NULL;
    git_status_list *status = NULL; git_index *index = NULL;
    git_tree *tree = NULL; git_commit *parent = NULL; git_signature *sig = NULL;
    git_reference *head = NULL, *remote_ref = NULL, *updated = NULL;
    git_object *object = NULL; int result = -1, r;
    char local_name[256], tracking[256], spec[600];
    struct credentials auth = {token, 0, error, cap};
    snprintf(local_name, sizeof(local_name), "refs/heads/%s", branch);
    snprintf(tracking, sizeof(tracking), "refs/remotes/origin/%s", branch);
    if (!git_reference_is_valid_name(local_name)) {message(error, cap, "Invalid branch name"); return -1;}
#define CHECK(expr, step) do {if ((r = (expr)) < 0) {git_failure(error, cap, step); if (r == GIT_EAUTH) result = -3; goto cleanup;}} while(0)
    r = git_repository_open_ext(&repo, path, GIT_REPOSITORY_OPEN_NO_SEARCH, NULL);
    if (r == GIT_ENOTFOUND) {
        CHECK(git_repository_init(&repo, path, 0), "Initialize notes repository");
        CHECK(git_repository_set_head(repo, local_name), "Set notes branch");
    } else if (r < 0) {git_failure(error, cap, "Open notes repository"); goto cleanup;}
    r = git_remote_lookup(&remote, repo, "origin");
    if (r == GIT_ENOTFOUND) {CHECK(git_remote_create(&remote, repo, "origin", url), "Set origin");}
    else if (r < 0) {git_failure(error, cap, "Read origin"); goto cleanup;}
    if (!git_remote_url(remote) || strcmp(git_remote_url(remote), url)) {
        message(error, cap, "This notes folder is linked to a different repository"); goto cleanup;
    }
    r = git_repository_head(&head, repo);
    if (r == 0 && strcmp(git_reference_name(head), local_name)) {
        git_reference *existing = NULL;
        int lookup = git_reference_lookup(&existing, repo, local_name);
        git_reference_free(existing);
        if (lookup != GIT_ENOTFOUND) {
            message(error, cap, "The target local branch already exists. Switch branches manually to preserve both histories.");
            goto cleanup;
        }
        /* Rename without checking out files: preserve all edits and commits. */
        git_reference *renamed = NULL;
        CHECK(git_branch_move(&renamed, head, branch, 0), "Select notes branch");
        git_reference_free(head); head = renamed;
        r = 0;
    }
    if (r < 0 && r != GIT_EUNBORNBRANCH && r != GIT_ENOTFOUND) {git_failure(error, cap, "Read local branch"); goto cleanup;}
    if (!head) CHECK(git_repository_set_head(repo, local_name), "Set initial notes branch");
    if (git_repository_state(repo) != GIT_REPOSITORY_STATE_NONE) {
        message(error, cap, "Finish the pending Git operation before syncing"); goto cleanup;
    }
    git_status_options so; git_status_options_init(&so, GIT_STATUS_OPTIONS_VERSION);
    so.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED | GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS;
    CHECK(git_status_list_new(&status, repo, &so), "Check local changes");
    int changed = git_status_list_entrycount(status) > 0;
    r = git_reference_lookup(&remote_ref, repo, tracking);
    if (!changed && head && r == 0 && git_oid_equal(git_reference_target(head), git_reference_target(remote_ref))) {
        result = 1; goto cleanup;
    }
    char probe[4096]; int http_status = 0;
    if (!strncmp(url, "https://", 8) && dn_http("HEAD", "https://api.github.com/", "", "", probe, sizeof(probe), &http_status, error, cap) != 0) {
        result = -2; goto cleanup;
    }
    if (changed) {
        CHECK(git_repository_index(&index, repo), "Open note index");
        CHECK(git_index_add_all(index, NULL, 0, NULL, NULL), "Stage notes");
        CHECK(git_index_update_all(index, NULL, NULL, NULL), "Stage deleted notes");
        CHECK(git_index_write(index), "Save note index");
        git_oid tree_id, id;
        CHECK(git_index_write_tree(&tree_id, index), "Write note tree");
        CHECK(git_tree_lookup(&tree, repo, &tree_id), "Read note tree");
        if (head) CHECK(git_commit_lookup(&parent, repo, git_reference_target(head)), "Read parent commit");
        if (!parent || !git_oid_equal(git_commit_tree_id(parent), &tree_id)) {
            CHECK(git_signature_now(&sig, name, email), "Create commit signature");
            const git_commit *parents[] = {parent};
            CHECK(git_commit_create(&id, repo, "HEAD", sig, sig, NULL, "Sync notes", tree, parent ? 1 : 0, parent ? parents : NULL), "Commit notes");
        }
        git_reference_free(head); head = NULL;
        CHECK(git_repository_head(&head, repo), "Read committed notes");
    }
    git_fetch_options fo; git_fetch_options_init(&fo, GIT_FETCH_OPTIONS_VERSION);
    fo.callbacks.credentials = credentials; fo.callbacks.payload = &auth;
    auth.attempts = 0;
    CHECK(git_remote_fetch(remote, NULL, &fo, NULL), "Fetch notes");
    git_reference_free(remote_ref); remote_ref = NULL;
    r = git_reference_lookup(&remote_ref, repo, tracking);
    if (r == 0) {
        const git_oid *their = git_reference_target(remote_ref);
        if (!head || !git_oid_equal(git_reference_target(head), their)) {
            int remote_ahead = head ? git_graph_descendant_of(repo, their, git_reference_target(head)) : 1;
            int local_ahead = head ? git_graph_descendant_of(repo, git_reference_target(head), their) : 0;
            if (remote_ahead < 0 || local_ahead < 0) {git_failure(error, cap, "Compare notes history"); goto cleanup;}
            if (!remote_ahead && !local_ahead) {message(error, cap, "Local and remote notes have diverged. No files were overwritten."); goto cleanup;}
            if (remote_ahead) {
                CHECK(git_object_lookup(&object, repo, their, GIT_OBJECT_COMMIT), "Read remote notes");
                git_checkout_options co; git_checkout_options_init(&co, GIT_CHECKOUT_OPTIONS_VERSION);
                co.checkout_strategy = GIT_CHECKOUT_SAFE | GIT_CHECKOUT_RECREATE_MISSING;
                CHECK(git_checkout_tree(repo, object, &co), "Update note files");
                CHECK(git_reference_create(&updated, repo, local_name, their, 1, "Sync notes fast-forward"), "Update notes branch");
                CHECK(git_repository_set_head(repo, local_name), "Select notes branch");
            }
        }
    } else if (r != GIT_ENOTFOUND) {git_failure(error, cap, "Read remote notes branch"); goto cleanup;}
    git_reference *current = NULL;
    r = git_repository_head(&current, repo);
    if (r == GIT_EUNBORNBRANCH || r == GIT_ENOTFOUND) {result = 1; goto cleanup;}
    if (r < 0) {git_failure(error, cap, "Read notes branch"); goto cleanup;}
    git_oid pushed = *git_reference_target(current); git_reference_free(current);
    snprintf(spec, sizeof(spec), "%s:%s", local_name, local_name);
    char *specs[] = {spec}; git_strarray refspecs = {specs, 1};
    git_push_options po; git_push_options_init(&po, GIT_PUSH_OPTIONS_VERSION);
    po.callbacks.credentials = credentials; po.callbacks.push_update_reference = push_status;
    po.callbacks.payload = &auth; auth.attempts = 0;
    CHECK(git_remote_push(remote, &refspecs, &po), "Push notes");
    git_reference_free(updated); updated = NULL;
    CHECK(git_reference_create(&updated, repo, tracking, &pushed, 1, "Notes pushed"), "Record sync state");
    result = 0;
cleanup:
    git_object_free(object); git_reference_free(updated); git_reference_free(remote_ref);
    git_reference_free(head); git_signature_free(sig); git_commit_free(parent);
    git_tree_free(tree); git_index_free(index); git_status_list_free(status);
    git_remote_free(remote); git_repository_free(repo);
    return result;
#undef CHECK
}

int dn_token_delete(const char *app, char *error, size_t cap) {
#ifdef _WIN32
    if (CredDeleteA(app, CRED_TYPE_GENERIC, 0) || GetLastError() == ERROR_NOT_FOUND) return 0;
    message(error, cap, "Windows Credential Manager could not remove the session");
#else
    GError *e = NULL;
    secret_password_clear_sync(&schema, NULL, &e, "application", app, NULL);
    if (!e) return 0;
    message(error, cap, e->message); g_error_free(e);
#endif
    return -1;
}
