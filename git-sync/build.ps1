$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$source = Join-Path $root '.deps/libgit2-1.9.2'
if (-not (Test-Path "$source/CMakeLists.txt")) {
    New-Item -ItemType Directory -Force "$root/.deps" | Out-Null
    Invoke-WebRequest 'https://github.com/libgit2/libgit2/archive/refs/tags/v1.9.2.tar.gz' -OutFile "$root/.deps/libgit2.tar.gz"
    if ((Get-FileHash "$root/.deps/libgit2.tar.gz" -Algorithm SHA256).Hash.ToLowerInvariant() -ne '6f097c82fc06ece4f40539fb17e9d41baf1a5a2fc26b1b8562d21b89bc355fe6') {throw 'libgit2 archive checksum mismatch'}
    & tar -xzf "$root/.deps/libgit2.tar.gz" -C "$root/.deps"
    if ($LASTEXITCODE -ne 0) {throw 'Could not unpack libgit2'}
}
& cmake -S $source -B "$root/.deps/libgit2-build-windows" -A x64 -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DUSE_SSH=OFF -DUSE_HTTPS=WinHTTP -DREGEX_BACKEND=builtin -DSTATIC_CRT=OFF
if ($LASTEXITCODE -ne 0) {throw 'libgit2 configure failed'}
& cmake --build "$root/.deps/libgit2-build-windows" --config Release
if ($LASTEXITCODE -ne 0) {throw 'libgit2 build failed'}
New-Item -ItemType Directory -Force "$PSScriptRoot/native/lib" | Out-Null
Copy-Item "$root/.deps/libgit2-build-windows/Release/git2.lib" "$PSScriptRoot/native/lib/git2.lib"
& clang -O2 -I "$source/include" -c "$PSScriptRoot/native/bridge.c" -o "$PSScriptRoot/native/bridge.obj"
if ($LASTEXITCODE -ne 0) {throw 'Native sync compilation failed'}
& llvm-lib "/OUT:$PSScriptRoot/native/sync.lib" "$PSScriptRoot/native/bridge.obj"
if ($LASTEXITCODE -ne 0) {throw 'Native sync archive failed'}
