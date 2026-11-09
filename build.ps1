param([switch]$Release)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $env:VCPKG_ROOT) { throw 'Set VCPKG_ROOT to your vcpkg installation.' }
$triplet = 'x64-windows'
$installed = Join-Path $env:VCPKG_ROOT "installed/$triplet"
$include = Join-Path $installed 'include'
$lib = Join-Path $installed 'lib'
$bin = Join-Path $installed 'bin'
foreach ($file in @("$include/ft2build.h", "$lib/freetype.lib", "$lib/SDL3.lib", "$lib/SDL3_image.lib", "$lib/cmark_static.lib")) {
    if (-not (Test-Path $file)) { throw "Missing $file. Install freetype, sdl3, sdl3-image, and cmark for $triplet." }
}
foreach ($tool in @('odin', 'clang', 'llvm-lib')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing $tool on PATH." }
}
$shared = Join-Path $root 'odin_shared'
New-Item -ItemType Directory -Force $shared | Out-Null
$clay = Join-Path $shared 'clay'
if (-not (Test-Path $clay)) {
    Copy-Item -Recurse (Join-Path $root 'shared/clay/bindings/odin/clay-odin') $clay
}
$font = Join-Path $root 'font'
& clang -O2 -I $include -c (Join-Path $font 'font.c') -o (Join-Path $font 'font.obj')
if ($LASTEXITCODE -ne 0) { throw 'Font compilation failed.' }
& llvm-lib "/OUT:$(Join-Path $font 'font.lib')" (Join-Path $font 'font.obj')
if ($LASTEXITCODE -ne 0) { throw 'Font archive creation failed.' }
$out = Join-Path $root 'build/windows'
New-Item -ItemType Directory -Force $out | Out-Null
New-Item -ItemType Directory -Force (Join-Path $out 'font'), (Join-Path $out 'packaging/icons') | Out-Null
$flags = if ($Release) { @('-o:speed', '-define:DOPE_NOTES_DEV=false') } else { @('-debug', '-define:DOPE_NOTES_DEV=true') }
& odin build $root "-collection:shared=$shared" "-out:$out/dope-notes.exe" "-extra-linker-flags:/LIBPATH:$lib" @flags
if ($LASTEXITCODE -ne 0) { throw 'Odin build failed.' }
Copy-Item "$bin/SDL3.dll", "$bin/SDL3_image.dll", "$bin/freetype.dll" $out
Copy-Item (Join-Path $root 'assets') $out -Recurse -Force
Copy-Item (Join-Path $root 'font/Roboto-Regular.ttf') (Join-Path $out 'font/Roboto-Regular.ttf') -Force
Copy-Item (Join-Path $root 'packaging/icons/dope-notes.png') (Join-Path $out 'packaging/icons/dope-notes.png') -Force
Write-Host "Built $out/dope-notes.exe"
