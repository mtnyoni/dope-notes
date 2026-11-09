param([switch]$SkipInstall)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}

foreach ($tool in @('git', 'odin', 'clang', 'llvm-lib')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Install $tool and add it to PATH, then rerun setup.ps1. See README.md."
    }
}
Invoke-Checked git @('-C', $root, 'submodule', 'sync', '--recursive')
Invoke-Checked git @('-C', $root, 'submodule', 'update', '--init', '--recursive')

if (-not $env:VCPKG_ROOT) { $env:VCPKG_ROOT = Join-Path $root '.deps/vcpkg' }
$vcpkg = Join-Path $env:VCPKG_ROOT 'vcpkg.exe'
if (-not $SkipInstall) {
    if (-not (Test-Path $env:VCPKG_ROOT)) {
        Invoke-Checked git @('clone', 'https://github.com/microsoft/vcpkg.git', $env:VCPKG_ROOT)
    }
    if (-not (Test-Path $vcpkg)) {
        Invoke-Checked (Join-Path $env:VCPKG_ROOT 'bootstrap-vcpkg.bat') @('-disableMetrics')
    }
    Invoke-Checked $vcpkg @('install', 'freetype:x64-windows', 'sdl3:x64-windows', 'sdl3-image[png]:x64-windows', '--recurse')
}
& (Join-Path $root 'build.ps1')
Write-Host 'Setup complete. Run: cd build/windows; ./dope-notes.exe'
