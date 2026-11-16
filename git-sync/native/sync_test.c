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
    require(sync_notes(local, remote, error) == -1, "failed push retains commit", error);
    require(rename(unavailable, remote) == 0, "restore remote", "");
    require(sync_notes(local, remote, error) == 0, "clean worktree retries unpushed commit", error);
    unlink(note);
    require(sync_notes(local, remote, error) == 0, "deleted note push", error);
    require(sync_notes(local, remote, error) == 1, "deletion recorded", error);
    /* An empty second client can safely fetch and check out the remote. */
    mkdir(reader, 0700);
    require(sync_notes(reader, remote, error) == 0, "empty client initial fetch", error);
    snprintf(second, sizeof(second), "%s/other.md", reader); write_note(second, "Remote edit\n");
    require(sync_notes(reader, remote, error) == 0, "second client push", error);
    write_note(note, "Preserve my local edits\n");
    require(sync_notes(local, remote, error) == -1, "divergence stops", error);
    FILE *f = fopen(note, "r"); char actual[100] = {0};
    require(f != NULL, "local note retained", error); fgets(actual, sizeof(actual), f); fclose(f);
    require(!strcmp(actual, "Preserve my local edits\n"), "divergence preserves local content", error);
    require(sync_notes(local, "/tmp/another-repo.git", error) == -1, "remote mismatch rejected", error);
    dn_native_shutdown();
    printf("Native sync regression checks passed (%s)\n", directory);
    return 0;
}
