# Dope Notes

A desktop notes editor built with Odin, SDL3, Clay, and FreeType. It includes a gap-buffer editor, note selection, Unicode text input, line wrapping, and mouse-wheel scrolling.

The focused note is saved to its Markdown file about once per second when its content changes, and also when switching notes or closing the app. Per-note cursor and scroll positions remain in memory.

Notebooks are stored under `$XDG_DATA_HOME`, defaulting to `~/.local/share`. Production RPMs use `dope-notes/notebooks`; development builds use `dope-notes-dev/notebooks`. Existing notes stay in the production directory. A fresh development directory starts with its own Default notebook and welcome note.

`just run`, `just build`, direct Odin builds, and `bash build.sh --debug` use development storage and display **Dope Notes (Development)** in the window title. RPMs and `bash build.sh --release` use production storage. To build production manually, pass `-define:DOPE_NOTES_DEV=false` to Odin.

Each immediate subdirectory is a notebook; its `.md` and `.markdown` files are notes. New Note opens a blank note, and the sidebar follows its title and first body line as you type.

## Supported setup

- **Linux:** native build and desktop application. The commands below target x86-64.
- **Windows:** native x64 build with PowerShell and vcpkg, or the Linux build through **WSL2 with WSLg**.

Linux compilation, tests, and a headless startup have been checked. Native Windows and WSLg builds have not been tested on a Windows machine.

## Quick setup

`git submodule sync --recursive` only synchronizes URLs for registered submodules; it does not download dependencies. Clay is now tracked as a real submodule at the revision used by these bindings. To fetch it yourself, use `git submodule update --init --recursive`.

Install Git and a recent [Odin](https://odin-lang.org/docs/install/) release on PATH first. On native Windows, also install LLVM (with `clang` and `llvm-lib`) and Visual Studio Build Tools with the **Desktop development with C++** workload and Windows SDK, as required by vcpkg. Use an x64 developer PowerShell terminal.

From a fresh or existing checkout:

```powershell
# Windows x64: downloads vcpkg, installs libraries, builds Clay and the app
.\setup.ps1
cd build\windows
.\dope-notes.exe
```

```sh
# Linux x86-64 / WSL: installs libraries with apt or dnf, builds Clay and the app
bash setup.sh
./build/fedora/dope-notes
```

The Linux script uses sudo for system packages and supports Fedora and Debian/Ubuntu releases that provide SDL3 and SDL3_image. On older distributions, follow the manual prerequisites below, then use `bash setup.sh --skip-install`. On Windows, vcpkg is stored in the ignored `.deps/vcpkg` directory unless `VCPKG_ROOT` is set. Subsequent builds find this local installation automatically. Use `.\setup.ps1 -SkipInstall` to reuse installed libraries. Both setup scripts can be rerun and produce a development build; `just` is optional.

## Native Windows build

Install x64 Odin, Git, LLVM (including `clang` and `llvm-lib`), and [vcpkg](https://learn.microsoft.com/en-us/vcpkg/get_started/get-started). Set `VCPKG_ROOT` to the vcpkg directory. In PowerShell, install the x64 dependencies and build:

```powershell
& "$env:VCPKG_ROOT\vcpkg.exe" install freetype:x64-windows sdl3:x64-windows sdl3-image[png]:x64-windows
.\build.ps1
cd build\windows
.\dope-notes.exe
```

Use `.\build.ps1 -Release` for production storage. Development notes go under `%APPDATA%\dope-notes-dev\notebooks`; release notes go under `%APPDATA%\dope-notes\notebooks`. The script copies runtime assets and DLLs beside the executable. Assets and fonts are resolved beside the executable, so it can be launched from any directory. The existing `justfile` and RPM packaging remain Linux workflows.

## Windows installer (Inno Setup)

Install Inno Setup 6 or 7, then run from PowerShell:

```powershell
.\package-windows.ps1 -Version 0.0.1
```

The script locates `ISCC.exe`, creates a release build, bundles the Visual Studio C++ runtime and dependency DLLs, and produces `build/installer/dope-notes-0.0.1-windows-x64-setup.exe`. Pass `-IsccPath 'C:\path\to\ISCC.exe'` for a custom installation. Visual Studio's C++ tools and redistributable files must be installed on the build machine.

The installer targets Windows 10 or newer (x64), installs under `%LOCALAPPDATA%\Programs\Dope Notes` without requiring administrator access, and creates a Start menu shortcut with an optional desktop shortcut. Notebooks remain under `%APPDATA%\dope-notes\notebooks` when upgrading or uninstalling. Use the same AppId for future releases to upgrade the existing installation. The generated installer is unsigned.

## Prerequisites

Install [Odin](https://odin-lang.org/docs/install/) and put its executable on `PATH`. Use a recent version that includes `vendor:sdl3`.

You also need Git, Clang, `ar` (binutils), `pkg-config`, the SDL3 and SDL3_image development libraries, CommonMark (`libcmark`), FreeType development headers, and [just](https://github.com/casey/just#installation).

The development environment used to check these instructions has Odin `dev-2026-09-nightly:a2fb372`, SDL3 `3.4.18`, and just `1.58.0`.

### Fedora

```sh
sudo dnf install git clang binutils pkgconf-pkg-config SDL3-devel SDL3_image-devel cmark-devel freetype-devel just
```

### Ubuntu / Debian / Ubuntu on WSL2

```sh
sudo apt update
sudo apt install git build-essential clang pkg-config libfreetype6-dev libcmark-dev
```

Install `just` using its [Linux release binary](https://github.com/casey/just/releases), or `sudo apt install just` if your distribution provides it. Install Odin's **Linux** release inside WSL, not `odin.exe` for Windows.

If your distribution provides SDL3, install it:

```sh
sudo apt install libsdl3-dev libsdl3-image-dev
```

If `libsdl3-dev` is unavailable, build SDL3 from source:

```sh
sudo apt install cmake ninja-build \
  libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev \
  libxfixes-dev libxss-dev libxtst-dev libxkbcommon-dev \
  libwayland-dev libdecor-0-dev libegl1-mesa-dev libgl1-mesa-dev

mkdir -p "$HOME/.local/src"
git clone --depth 1 --branch release-3.4.18 \
  https://github.com/libsdl-org/SDL.git "$HOME/.local/src/SDL3"
cmake -S "$HOME/.local/src/SDL3" -B "$HOME/.local/src/SDL3/build" \
  -G Ninja -DCMAKE_BUILD_TYPE=Release -DSDL_SHARED=ON -DSDL_STATIC=OFF
cmake --build "$HOME/.local/src/SDL3/build"
sudo cmake --install "$HOME/.local/src/SDL3/build"
sudo ldconfig
```

See SDL's [Linux dependencies](https://wiki.libsdl.org/SDL3/README-linux) and [CMake build guide](https://wiki.libsdl.org/SDL3/README-cmake) for platform-specific details.

Check that the tools and libraries are available:

```sh
odin version
just --version
pkg-config --modversion freetype2 sdl3
```

## Clone and prepare the project

Run the following in a Linux shell, including the Ubuntu shell when using WSL2:

```sh
git clone https://github.com/mtnyoni/dope-notes.git
cd dope-notes
```

Initialize the pinned Clay submodule (also done by either setup script):

```sh
git submodule update --init --recursive
```

The following manual steps are only needed if you did not use `setup.sh`.

Build Clay for the host system and create the import collection:

```sh
mkdir -p shared/clay/bindings/odin/clay-odin/linux
clang -x c -DCLAY_IMPLEMENTATION -O2 -fPIC \
  -c shared/clay/clay.h \
  -o shared/clay/bindings/odin/clay-odin/linux/clay.o
ar rcs shared/clay/bindings/odin/clay-odin/linux/clay.a \
  shared/clay/bindings/odin/clay-odin/linux/clay.o
just setup-shared
just font-build
```

`setup-shared` creates this symbolic link, allowing `import clay "shared:clay"`:

```text
odin_shared/clay -> ../shared/clay/bindings/odin/clay-odin
```

`font-build` compiles the C/FreeType bridge into `font/font.a`. Rebuild it after changing `font/font.c` or moving to another platform. The included `font/Roboto-Regular.ttf` is loaded at runtime.

## Run and build

Run commands from the repository root so the font path resolves:

```sh
just run
```

Build an executable and launch it:

```sh
just build
./dope-notes
```

Both recipes create the collection link, rebuild the font bridge, and pass `-collection:shared=./odin_shared`. Rebuilding the bridge keeps its native font functions in sync with the Odin bindings.

The equivalent run command is:

```sh
odin run . -collection:shared=./odin_shared
```

The compiler accepts one package path. Do not append `./ui/clay` or use `-no-entry-point` when running the application.

## Windows setup with WSL2

Use Windows 11 or Windows 10 build 19044 or newer, with WSL2 and WSLg. See Microsoft's [Linux GUI application guide](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps).

In an administrator PowerShell terminal:

```powershell
wsl --install -d Ubuntu
wsl --update
wsl --list --verbose
```

Restart Windows if prompted. Confirm Ubuntu uses version `2`; if it uses version `1`, convert it:

```powershell
wsl --set-version Ubuntu 2
```

Open Ubuntu, finish its user setup, and follow the **Ubuntu dependencies**, **Clone and prepare**, and **Run and build** sections above. Keep the checkout inside the Linux filesystem, for example `~/projects/dope-notes`. WSLg displays the application as a window on your Windows desktop.

For editor integration, open the repository through your editor's WSL connection and run the Linux Odin/OLS tools inside WSL. The Linux `justfile` recipes are not commands for a native PowerShell checkout.

## Code completion and hover

Install [OLS](https://github.com/DanielGavin/ols#configuration) and your editor's Odin language support. Open the repository root as the workspace.

The checked-in `ols.json` contains a developer-specific absolute path. Replace it with the absolute path to **your** `odin_shared` directory in both settings:

```json
{
  "collections": [
    {"name": "shared", "path": "/absolute/path/to/dope-notes/odin_shared"}
  ],
  "checker_args": "-collection:shared=/absolute/path/to/dope-notes/odin_shared",
  "enable_hover": true,
  "enable_document_symbols": true,
  "enable_snippets": true
}
```

Inside WSL, use the Linux path, not a `C:\\...` path. Run `just setup-shared` and restart OLS after editing the configuration. `ols.json` configures the language server; terminal compiler commands still need the collection flag.

## Live Markdown editing

The source line containing the cursor is editable and displays its Markdown markers. Other lines render through CommonMark with headings, paragraphs, bold and italic text, lists, quotes, code blocks, rules, and styled link labels. Click rendered text or use the arrow keys to move the cursor; the previous line returns to formatted rendering automatically. There is no separate Edit/Preview mode. Per-note edits remain in memory when switching notes.

The renderer uses Odin's `vendor:commonmark` binding. Windows uses `cmark_static.lib` bundled with Odin; vcpkg's `cmark.lib` and `cmark.dll` are unnecessary. Linux links `libcmark`; install it before building:

```sh
# Fedora
sudo dnf install cmark-devel

# Ubuntu / Debian / WSL Ubuntu
sudo apt install libcmark-dev
```

## Checks and tests

Run from the repository root after building the dependencies:

```sh
odin check . -collection:shared=./odin_shared
odin test buffer
odin test markdown -collection:shared=./odin_shared
odin test state -collection:shared=./odin_shared
odin test ui -collection:shared=./odin_shared
odin test ui/clay -collection:shared=./odin_shared
```

## Troubleshooting

- **`Path does not exist: shared:clay`:** check that Clay was cloned, run `just setup-shared`, and pass the collection flag. For editor errors, update `ols.json` and restart OLS.
- **Missing `-lcmark` at link time:** install `cmark-devel` (Fedora) or `libcmark-dev` (Ubuntu/Debian).
- **Missing `font/font.a`, styled-font symbols, or `ft2build.h`:** install FreeType development headers and run `just font-build`.
- **Missing `SDL3` at link time:** install SDL3 development files; `pkg-config --modversion sdl3` should succeed. If built from source, run `sudo ldconfig`.
- **`No available video device`:** launch from a graphical Linux session or a WSL2 session with WSLg. For WSL, update WSL and restart it with `wsl --shutdown` in PowerShell before reopening Ubuntu.
- **Renderer initialization fails:** try `SDL_RENDER_DRIVER=software just run` to use software rendering.
- **Font fails to load:** run from the repository root and confirm `font/Roboto-Regular.ttf` exists.
- **Headless environment:** `SDL_VIDEODRIVER=dummy just run` checks startup without displaying a window. Stop it with Ctrl+C; the dummy driver may not support OS cursors.

## GitHub notebook sync

Install [GitHub CLI](https://cli.github.com/) and Git, then sign in with `gh auth login`. Set `DOPE_NOTES_GITHUB_REPO` to the target `owner/repo` before starting Dope Notes. Configure your Git commit identity (`git config --global user.name` and `git config --global user.email`). Press **Ctrl+Shift+G** in the app to save the active note, pull the repository's `main` branch, and push the notebooks. The app uses the currently authenticated `gh` account and stores no GitHub token. Sync results and errors appear in the launching terminal.

Use a repository dedicated to notebooks. On the first sync, an empty repository is simplest; an existing `main` branch must have compatible history. If Git reports a conflict, resolve it in the notebook storage directory before syncing again. Sync is manual and runs on the app's main thread, so the window may pause during network operations.
