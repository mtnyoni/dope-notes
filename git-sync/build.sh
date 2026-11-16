#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$root/.deps/libgit2-1.9.2"
if [[ ! -f "$source_dir/CMakeLists.txt" ]]; then
    mkdir -p "$root/.deps"
    curl --fail --location --proto '=https' --tlsv1.2 https://github.com/libgit2/libgit2/archive/refs/tags/v1.9.2.tar.gz -o "$root/.deps/libgit2.tar.gz"
    printf '%s  %s\n' 6f097c82fc06ece4f40539fb17e9d41baf1a5a2fc26b1b8562d21b89bc355fe6 "$root/.deps/libgit2.tar.gz" | sha256sum --check --status
    tar -xzf "$root/.deps/libgit2.tar.gz" -C "$root/.deps"
fi
if [[ "${1:-}" == "--fetch-only" ]]; then exit 0; fi
for tool in cmake clang ar curl pkg-config; do
    command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done
pkg-config --exists openssl libcurl libsecret-1 || {
    echo 'Install build dependencies: sudo dnf install cmake openssl-devel libcurl-devel libsecret-devel zlib-devel' >&2
    exit 1
}
cmake -S "$source_dir" -B "$root/.deps/libgit2-build" \
    -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_CLI=OFF \
    -DUSE_SSH=OFF -DUSE_HTTPS=OpenSSL -DREGEX_BACKEND=builtin \
    -DUSE_NTLMCLIENT=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$root/.deps/libgit2-build" --parallel 4
mkdir -p "$root/git-sync/native/lib"
cp "$root/.deps/libgit2-build/libgit2.a" "$root/git-sync/native/lib/"
clang -std=c11 -O2 -Wall -Wextra -Wno-unused-parameter -fPIC \
    -I "$source_dir/include" $(pkg-config --cflags libcurl libsecret-1) \
    -c "$root/git-sync/native/bridge.c" -o "$root/git-sync/native/bridge.o"
ar rcs "$root/git-sync/native/sync.a" "$root/git-sync/native/bridge.o"
