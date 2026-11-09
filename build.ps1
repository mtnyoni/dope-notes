param([switch]$Release)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $env:VCPKG_ROOT) { $env:VCPKG_ROOT = Join-Path $root '.deps/vcpkg' }
$triplet = 'x64-windows'
$installed = Join-Path $env:VCPKG_ROOT "installed/$triplet"
$include = Join-Path $installed 'include'
$lib = Join-Path $installed 'lib'
$bin = Join-Path $installed 'bin'
# vendor:commonmark links Odin's bundled cmark_static.lib on Windows.
foreach ($file in @("$include/ft2build.h", "$lib/freetype.lib", "$lib/SDL3.lib", "$lib/SDL3_image.lib")) {
    if (-not (Test-Path $file)) { throw "Missing $file. Install freetype, sdl3, and sdl3-image for $triplet." }
}
foreach ($tool in @('odin', 'clang', 'llvm-lib')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing $tool on PATH." }
}
$shared = Join-Path $root 'odin_shared'
New-Item -ItemType Directory -Force $shared | Out-Null
$clay = Join-Path $shared 'clay'
$claySource = Join-Path $root 'shared/clay/bindings/odin/clay-odin'
if (-not (Test-Path $claySource)) { throw 'Clay is missing. Run ./setup.ps1 first.' }
if (Test-Path $clay -PathType Leaf) {
    # Git can check out a Linux symlink as a text file on Windows.
    if ((Get-Content -LiteralPath $clay -Raw).Trim() -ne '../shared/clay/bindings/odin/clay-odin') {
        throw "Expected a directory at $clay. Move this file aside and rerun the build."
    }
    Remove-Item -LiteralPath $clay
}
New-Item -ItemType Directory -Force $clay | Out-Null
Copy-Item "$claySource/*" $clay -Recurse -Force
$clayWindows = Join-Path $clay 'windows'
New-Item -ItemType Directory -Force $clayWindows | Out-Null
& clang -x c -DCLAY_IMPLEMENTATION -O2 -c (Join-Path $root 'shared/clay/clay.h') -o (Join-Path $clayWindows 'clay.obj')
if ($LASTEXITCODE -ne 0) { throw 'Clay compilation failed.' }
& llvm-lib "/OUT:$(Join-Path $clayWindows 'clay.lib')" (Join-Path $clayWindows 'clay.obj')
if ($LASTEXITCODE -ne 0) { throw 'Clay archive creation failed.' }
$font = Join-Path $root 'font'
& clang -O2 -I $include -c (Join-Path $font 'font.c') -o (Join-Path $font 'font.obj')
if ($LASTEXITCODE -ne 0) { throw 'Font compilation failed.' }
& llvm-lib "/OUT:$(Join-Path $font 'font.lib')" (Join-Path $font 'font.obj')
if ($LASTEXITCODE -ne 0) { throw 'Font archive creation failed.' }
$out = Join-Path $root 'build/windows'
New-Item -ItemType Directory -Force $out | Out-Null
New-Item -ItemType Directory -Force (Join-Path $out 'font'), (Join-Path $out 'packaging/icons') | Out-Null
$flags = if ($Release) { @('-o:speed', '-define:DOPE_NOTES_DEV=false') } else { @('-debug', '-define:DOPE_NOTES_DEV=true') }
$icon = (Join-Path $root 'packaging/icons/dope-notes.ico').Replace('\', '/')
$resource = Join-Path $out 'dope-notes.rc'
Set-Content -LiteralPath $resource -Value "1 ICON `"$icon`"" -Encoding ASCII
& odin build $root "-collection:shared=$shared" "-out:$out/dope-notes.exe" '-subsystem:windows' "-resource:$resource" "-extra-linker-flags:/LIBPATH:$lib" @flags
if ($LASTEXITCODE -ne 0) { throw 'Odin build failed.' }
Copy-Item "$bin/*.dll" $out -Force
Copy-Item (Join-Path $root 'assets') $out -Recurse -Force
Copy-Item (Join-Path $root 'font/Roboto-Regular.ttf') (Join-Path $out 'font/Roboto-Regular.ttf') -Force
Copy-Item (Join-Path $root 'packaging/icons/dope-notes.png') (Join-Path $out 'packaging/icons/dope-notes.png') -Force
Write-Host "Built $out/dope-notes.exe"
