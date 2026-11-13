# Dope Notes

A desktop notes editor built with Odin, SDL3, Clay, and FreeType. It includes a gap-buffer editor, note selection, Unicode text input, line wrapping, and mouse-wheel scrolling.

Display equations use `$$` delimiters, either on their own lines or around a single-line equation. The built-in renderer supports fractions (`\frac{1}{2}`), superscripts (`v^2`), subscripts (`x_{1}`), grouped expressions, common Greek letters such as `\rho`, and literal text (`\text{constant}`). The preview updates while the active source line remains editable. This is a subset of LaTeX notation; unsupported commands remain visible as text. Math inside fenced code blocks is left unchanged.

The focused note is saved to its Markdown file about once per second when its content changes, and also when switching notes or closing the app. Per-note cursor and scroll positions remain in memory.

On Linux, notebooks are stored under `$XDG_DATA_HOME`, defaulting to `~/.local/share`. On Windows, they are stored under `%APPDATA%`. Production RPMs use `dope-notes/notebooks`; development builds use `dope-notes-dev/notebooks`. Existing notes stay in the production directory. A fresh development directory starts with its own Default notebook and welcome note.

`just run`, `just build`, direct Odin builds, and `bash build.sh --debug` use development storage and display **Dope Notes (Development)** in the window title. RPMs and `bash build.sh --release` use production storage. To build production manually, pass `-define:DOPE_NOTES_DEV=false` to Odin.

Each immediate subdirectory is a notebook; its `.md` and `.markdown` files are notes. New Note opens a blank note, and the sidebar follows its title and first body line as you type.

## Supported setup

- **Linux:** native build and desktop application. The commands below target x86-64.
- **Windows:** native x64 build with PowerShell and vcpkg, or the Linux build through **WSL2 with WSLg**.

The instructions below follow the checked-in setup and build scripts. The development environment previously used for Linux checks is listed below; verify builds on your own machine after installing the prerequisites.

## Developer setup: Windows (native x64)

### 1. Install the required software

Install these before running the project scripts:

| Software | Purpose / installation notes |
| --- | --- |
| [Git for Windows](https://git-scm.com/downloads/win) | Clones the app, Clay submodule, and vcpkg. Make `git` available in the terminal. |
| [Odin](https://odin-lang.org/docs/install/) (Windows x64) | Download and extract a recent release that includes `vendor:sdl3` and `vendor:commonmark`. Add the directory containing `odin.exe` to your user `PATH`; keep the complete distribution, including its `core` and `vendor` directories. |
| [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/) | In Visual Studio Installer, select **Desktop development with C++**, including the MSVC x64/x86 build tools and a Windows SDK. A full Visual Studio installation with this workload also works. |
| [LLVM](https://releases.llvm.org/) (Windows x64) | Install `clang` and `llvm-lib`, and add LLVM's `bin` directory to `PATH`. These compile and archive the Clay and FreeType bridges. |
| vcpkg | Downloaded and bootstrapped by `setup.ps1`; a separate installation is optional. It installs FreeType, SDL3, SDL3_image with PNG support, and their dependencies. |

Use **Developer PowerShell for Visual Studio** with an x64 target environment (or an x64 Native Tools terminal running PowerShell). Reopen the terminal after changing `PATH`. Verify the tools:

```powershell
git --version
odin version
clang --version
llvm-lib /?
Get-Command cl, link, rc
```

`cl`, `link`, and `rc` come from the Visual Studio tools and Windows SDK. If any command is missing, correct the installation or terminal environment before continuing. First setup requires internet access to download dependencies.

### 2. Clone and set up the app

```powershell
git clone --recurse-submodules https://github.com/mtnyoni/dope-notes.git
cd dope-notes
.\setup.ps1
```

For an existing checkout, run `setup.ps1` from its root. The script initializes the pinned Clay submodule, downloads vcpkg into `.deps/vcpkg` unless `VCPKG_ROOT` is set, installs native libraries, and builds the app. No separate Clay or CommonMark installation is required: Clay is in the submodule and Windows CommonMark is bundled with Odin.

If PowerShell blocks local scripts, allow them for the current terminal session, then rerun setup:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup.ps1
```

### 3. Run and rebuild

```powershell
.\build\windows\dope-notes.exe

# Rebuild after source changes; dependencies are already installed.
.\build.ps1
.\build\windows\dope-notes.exe

# Optimized release build using production notebook storage.
.\build.ps1 -Release
```

The build copies fonts, icons, and runtime DLLs beside the executable. Keep those files together; the executable can be launched from any working directory. Development notes go under `%APPDATA%\dope-notes-dev\notebooks`; release notes go under `%APPDATA%\dope-notes\notebooks`.

To reuse dependencies while rerunning the full setup, use `.\setup.ps1 -SkipInstall`. To use an existing vcpkg installation, set its root before setup or build:

```powershell
$env:VCPKG_ROOT = 'C:\dev\vcpkg'
& "$env:VCPKG_ROOT\vcpkg.exe" install freetype:x64-windows sdl3:x64-windows 'sdl3-image[png]:x64-windows'
.\build.ps1
```

`just`, Bash, WSL, OLS, GitHub CLI, and Inno Setup are not required for native development. The `justfile` and RPM packaging are Linux workflows.

## Developer setup: Linux (x86-64)

### 1. Install Git and Odin

Install Git with your distribution's package manager (`sudo apt install git` on Debian/Ubuntu, or `sudo dnf install git` on Fedora). Download and extract a recent **Linux x86-64** [Odin release](https://odin-lang.org/docs/install/) that includes `vendor:sdl3` and `vendor:commonmark`. Keep the complete distribution and add its directory to `PATH`.

For example, if you extracted it to `$HOME/tools/odin`, add this line to your shell's startup file (such as `~/.bashrc`), then open a new terminal:

```sh
export PATH="$HOME/tools/odin:$PATH"
```

Confirm `git --version` and `odin version` work. You need Bash, a graphical desktop session (Wayland or X11), internet access for first setup, and permission to install system packages through `sudo`.

### 2. Clone and install dependencies

```sh
git clone --recurse-submodules https://github.com/mtnyoni/dope-notes.git
cd dope-notes
bash setup.sh
```

The script supports `apt-get` and `dnf`. It installs Clang, `ar`/binutils, `pkg-config`, FreeType development files, CommonMark, SDL3, and SDL3_image; initializes Clay; builds Clay and the font bridge; and compiles a development executable. **Odin must already be installed.**

If your distribution does not provide SDL3 and SDL3_image packages, use the manual prerequisites below and then run `bash setup.sh --skip-install`. Use the same option on other distributions after installing equivalent packages yourself. `git submodule sync --recursive` alone does not download Clay; use `git submodule update --init --recursive` if preparing dependencies manually.

### 3. Run and rebuild

Run from the repository root so the Linux development build can find its fonts and icons:

```sh
./build/fedora/dope-notes

# Rebuild after source changes.
bash build.sh --debug
./build/fedora/dope-notes

# Optimized release build using production notebook storage.
bash build.sh --release
```

`build/fedora` is the output directory on all supported Linux distributions, including Debian/Ubuntu. `build.sh` defaults to release mode if no argument is supplied. It rebuilds the font bridge but assumes Clay was already prepared by setup.

Development notes go under `${XDG_DATA_HOME:-$HOME/.local/share}/dope-notes-dev/notebooks`; release notes go under `${XDG_DATA_HOME:-$HOME/.local/share}/dope-notes/notebooks`. The app creates the notebook directory on first launch.

`just` is optional for the convenience commands below. OLS/editor support, GitHub sync tools, and packaging tools are also optional.

## Windows installer (Inno Setup)

Install Inno Setup 6 or 7, then run from PowerShell:

```powershell
.\package-windows.ps1 -Version 0.0.1
```

The script locates `ISCC.exe`, creates a release build, bundles the Visual Studio C++ runtime and dependency DLLs, and produces `build/installer/dope-notes-0.0.1-windows-x64-setup.exe`. Pass `-IsccPath 'C:\path\to\ISCC.exe'` for a custom installation. Visual Studio's C++ tools and redistributable files must be installed on the build machine.

The installer targets Windows 10 or newer (x64), installs under `%LOCALAPPDATA%\Programs\Dope Notes` without requiring administrator access, and creates a Start menu shortcut with an optional desktop shortcut. Notebooks remain under `%APPDATA%\dope-notes\notebooks` when upgrading or uninstalling. Use the same AppId for future releases to upgrade the existing installation. The generated installer is unsigned.

## Manual Linux prerequisites

Install [Odin](https://odin-lang.org/docs/install/) and put its executable on `PATH`. Use a recent version that includes `vendor:sdl3`.

You also need Git, Clang, `ar` (binutils), `pkg-config`, the SDL3 and SDL3_image development libraries, CommonMark (`libcmark`), FreeType development headers, and Bash. Install [just](https://github.com/casey/just#installation) only if you want to use the `just` recipes.

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

If SDL3 packages are unavailable, build SDL3 and SDL3_image from source. The following installs shared libraries under `/usr/local`:

```sh
sudo apt install cmake ninja-build libpng-dev \
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

# SDL3_image is required too; building SDL3 alone is insufficient.
git clone --depth 1 https://github.com/libsdl-org/SDL_image.git \
  "$HOME/.local/src/SDL3_image"
cmake -S "$HOME/.local/src/SDL3_image" -B "$HOME/.local/src/SDL3_image/build" \
  -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
  -DSDLIMAGE_PNG=ON -DSDLIMAGE_PNG_VENDORED=OFF
cmake --build "$HOME/.local/src/SDL3_image/build"
sudo cmake --install "$HOME/.local/src/SDL3_image/build"
sudo ldconfig
```

See SDL's [Linux dependencies](https://wiki.libsdl.org/SDL3/README-linux) and [CMake build guide](https://wiki.libsdl.org/SDL3/README-cmake) for platform-specific details.

Check that the tools and libraries are available:

```sh
odin version
clang --version
ar --version
pkg-config --modversion freetype2 sdl3 SDL3_image libcmark
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
mkdir -p odin_shared
ln -sfnT ../shared/clay/bindings/odin/clay-odin odin_shared/clay
bash font/build.sh
```

The `ln` command (also available as `just setup-shared`) creates this symbolic link, allowing `import clay "shared:clay"`:

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

Inside WSL, use the Linux path, not a `C:\\...` path. Run the platform setup script and restart OLS after editing the configuration. On Windows, use a path such as `C:/dev/dope-notes/odin_shared` in both settings. `ols.json` configures the language server; terminal compiler commands still need the collection flag.

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
- **Windows missing DLL at launch:** rerun `.\build.ps1` and launch the executable inside `build/windows` with its copied DLLs and resource folders.
- **Windows missing `clang`, `llvm-lib`, or SDK tools:** reopen an x64 Visual Studio developer terminal and check the LLVM `bin` directory is on `PATH`.
- **Missing `SDL3_image` at link time:** install `SDL3_image-devel` (Fedora) or `libsdl3-image-dev` (Debian/Ubuntu), or build SDL3_image as above. Check `pkg-config --modversion SDL3_image`.
- **Missing `SDL3` at link time:** install SDL3 development files; `pkg-config --modversion sdl3` should succeed. If built from source, run `sudo ldconfig`.
- **`No available video device`:** launch from a graphical Linux session or a WSL2 session with WSLg. For WSL, update WSL and restart it with `wsl --shutdown` in PowerShell before reopening Ubuntu.
- **Renderer initialization fails:** try `SDL_RENDER_DRIVER=software just run` to use software rendering.
- **Font fails to load:** run from the repository root and confirm `font/Roboto-Regular.ttf` exists.
- **Headless environment:** `SDL_VIDEODRIVER=dummy just run` checks startup without displaying a window. Stop it with Ctrl+C; the dummy driver may not support OS cursors.

## GitHub notebook sync

Install [GitHub CLI](https://cli.github.com/) and Git, then sign in with `gh auth login`. Set `DOPE_NOTES_GITHUB_REPO` to the target `owner/repo` before starting Dope Notes. Configure your Git commit identity (`git config --global user.name` and `git config --global user.email`). Press **Ctrl+Shift+G** in the app to save the active note, pull the repository's `main` branch, and push the notebooks. The app uses the currently authenticated `gh` account and stores no GitHub token. Sync results and errors appear in the launching terminal.

Use a repository dedicated to notebooks. On the first sync, an empty repository is simplest; an existing `main` branch must have compatible history. If Git reports a conflict, resolve it in the notebook storage directory before syncing again. Sync is manual and runs on the app's main thread, so the window may pause during network operations.
