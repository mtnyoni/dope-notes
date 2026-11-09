param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version = '0.0.1',
    [string]$IsccPath
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $IsccPath) {
    $compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($compiler) { $IsccPath = $compiler.Source }
}
if (-not $IsccPath) {
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs")) {
        if (-not $base) { continue }
        foreach ($major in @(7, 6)) {
            $candidate = Join-Path $base "Inno Setup $major/ISCC.exe"
            if (Test-Path $candidate) { $IsccPath = $candidate; break }
        }
        if ($IsccPath) { break }
    }
}
if (-not $IsccPath -or -not (Test-Path $IsccPath)) {
    throw 'Install Inno Setup 6 or 7, or pass -IsccPath with the full path to ISCC.exe.'
}
# Always build a release so installed notebooks use production storage.
& (Join-Path $root 'build.ps1') -Release
# Include the app-local Microsoft runtime used by vcpkg's dynamic libraries.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path $vswhere)) { throw 'Visual Studio Installer vswhere.exe is required to locate the redistributable C++ runtime.' }
$vsRoot = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $vsRoot) { throw 'Could not locate Visual Studio C++ tools.' }
$runtime = Get-ChildItem (Join-Path $vsRoot 'VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT') -Directory |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $runtime) { throw 'Install the Visual Studio C++ redistributable files before packaging.' }
Copy-Item (Join-Path $runtime.FullName '*.dll') (Join-Path $root 'build/windows') -Force
& $IsccPath "/DAppVersion=$Version" (Join-Path $root 'packaging/windows/dope-notes.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE." }
Write-Host "Installer: $root/build/installer/dope-notes-$Version-windows-x64-setup.exe"
