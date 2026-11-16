#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$root/git-sync/build.sh"
test_binary="$(mktemp /tmp/dope-sync-regression.XXXXXX)"
trap 'rm -f "$test_binary"' EXIT
clang -std=c11 -O1 -g -fsanitize=address,undefined \
    -I "$root/.deps/libgit2-1.9.2/include" \
    $(pkg-config --cflags libcurl libsecret-1) \
    "$root/git-sync/native/bridge.c" "$root/git-sync/native/sync_test.c" \
    "$root/git-sync/native/lib/libgit2.a" \
    $(pkg-config --libs libcurl libsecret-1 openssl) \
    -lz -lpthread -ldl -o "$test_binary"
# Set ASAN_OPTIONS=detect_leaks=0 only in environments where LeakSanitizer
# cannot inspect processes (for example, a ptrace sandbox).
"$test_binary"
