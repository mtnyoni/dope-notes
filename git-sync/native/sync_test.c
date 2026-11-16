#define _GNU_SOURCE
#include <git2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int dn_native_init(void);
void dn_native_shutdown(void);
int dn_sync(const char *, const char *, const char *, const char *, const char *, const char *, char *, size_t);
static void require(int condition, const char *label, const char *error) {
    if (!condition) {fprintf(stderr, "FAIL %s: %s\n", label, error); exit(1);}
}
static int count_stash(size_t index, const char *message, const git_oid *id, void *payload) {
    (void)index; (void)message; (void)id; (*(int *)payload)++; return 0;
}
static void write_note(const char *path, const char *text) {
    FILE *f = fopen(path, "w"); require(f != NULL, "open note", path);
    fputs(text, f); fclose(f);
}
static int sync_notes(const char *local, const char *remote, char *error) {
    error[0] = 0;
    return dn_sync(local, remote, "main", "unused", "Test", "test@example.invalid", error, 2048);
}
int main(void) {
    char directory[] = "/tmp/dope-sync-test-XXXXXX";
    require(mkdtemp(directory) != NULL, "temporary directory", "");
    char remote[512], local[512], reader[512], note[600], second[600], error[2048];
    snprintf(remote, sizeof(remote), "%s/remote.git", directory);
    snprintf(local, sizeof(local), "%s/local", directory);
    snprintf(reader, sizeof(reader), "%s/reader", directory);
    snprintf(note, sizeof(note), "%s/note.md", local);
    require(dn_native_init() == 0, "initialize", "");
    git_repository *repo = NULL;
    require(git_repository_init(&repo, remote, 1) == 0, "bare repository", "");
    git_repository_set_head(repo, "refs/heads/main"); git_repository_free(repo);
    mkdir(local, 0700); write_note(note, "First note\n");
    require(sync_notes(local, remote, error) == 0, "first commit and push", error);
    require(sync_notes(local, remote, error) == 1, "unchanged skips sync", error);
    write_note(note, "Changed\n");
    require(sync_notes(local, remote, error) == 0, "updated note push", error);
    char unavailable[600]; snprintf(unavailable, sizeof(unavailable), "%s/unavailable.git", directory);
    require(rename(remote, unavailable) == 0, "make remote unavailable", "");
    write_note(note, "Unpushed note\n");
    require(sync_notes(local, remote, error) == -1, "failed fetch restores local edits", error);
    require(rename(unavailable, remote) == 0, "restore remote", "");
    require(sync_notes(local, remote, error) == 0, "retry sync after remote recovery", error);
    unlink(note);
    require(sync_notes(local, remote, error) == 0, "deleted note push", error);
    require(sync_notes(local, remote, error) == 1, "deletion recorded", error);
    /* An empty second client can safely fetch and check out the remote. */
    mkdir(reader, 0700);
    require(sync_notes(reader, remote, error) == 0, "empty client initial fetch", error);
    snprintf(second, sizeof(second), "%s/other.md", reader); write_note(second, "Remote edit\n");
    require(sync_notes(reader, remote, error) == 0, "second client push", error);
    write_note(note, "Preserve my local edits\n");
    require(sync_notes(local, remote, error) == 0, "stash pull restore and push independent changes", error);
    FILE *f = fopen(note, "r"); char actual[100] = {0};
    require(f != NULL, "local note retained", error); fgets(actual, sizeof(actual), f); fclose(f);
    require(!strcmp(actual, "Preserve my local edits\n"), "divergence preserves local content", error);
    char imported[600]; snprintf(imported, sizeof(imported), "%s/other.md", local);
    require(access(imported, F_OK) == 0, "remote note pulled alongside local edit", error);
    require(sync_notes(reader, remote, error) == 0, "clean client pulls remote-only notes", error);
    char reader_note[600]; snprintf(reader_note, sizeof(reader_note), "%s/note.md", reader);
    write_note(reader_note, "Remote conflicting edit\n");
    require(sync_notes(reader, remote, error) == 0, "push remote conflicting edit", error);
    write_note(note, "Local conflicting edit\n");
    require(sync_notes(local, remote, error) == -1, "conflicting stash restoration stops", error);
    git_repository *conflicted = NULL;
    require(git_repository_open(&conflicted, local) == 0, "open conflict repository", error);
    int stash_count = 0; git_stash_foreach(conflicted, count_stash, &stash_count);
    require(stash_count > 0, "conflicting local edits retained in stash", error);
    git_repository_free(conflicted);
    require(sync_notes(local, "/tmp/another-repo.git", error) == -1, "remote mismatch rejected", error);
    require(dn_sync(reader, remote, "dev", "unused", "Test", "test@example.invalid", error, sizeof(error)) == 0,
        "rename existing local branch to dev and sync", error);
    git_repository *verify = NULL; git_oid main_id, dev_id;
    require(git_repository_open(&verify, remote) == 0, "open remote branches", "");
    require(git_reference_name_to_id(&main_id, verify, "refs/heads/main") == 0, "production branch retained", "");
    require(git_reference_name_to_id(&dev_id, verify, "refs/heads/dev") == 0, "development branch created", "");
    require(git_oid_equal(&main_id, &dev_id), "branch migration preserves history", "");
    git_repository_free(verify);
    dn_native_shutdown();
    printf("Native sync regression checks passed (%s)\n", directory);
    return 0;
}
