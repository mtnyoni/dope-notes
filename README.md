# Dope Notes

A desktop notes editor built with Odin, SDL3, Clay, and FreeType. It includes a gap-buffer editor, note selection, Unicode text input, line wrapping, and mouse-wheel scrolling.

Edits and per-note cursor/scroll positions are currently kept in memory. Changes are not saved to disk yet.

Notebooks are loaded at startup from `markdown/files/`. Each immediate subdirectory is a notebook; its `.md` and `.markdown` files are notes. The app selects `business planning` by default, or the first notebook if that folder is absent. The sidebar reads `title` and `description` from flat front matter, with heading/filename and first-paragraph fallbacks for plain Markdown. Notebook creation and switching controls are planned; application state already supports selecting a notebook by path.

## Supported setup

- **Linux:** native build and desktop application. The commands below target x86-64.
- **Windows:** run the Linux build through **WSL2 with WSLg**. Native Windows builds are not configured: the font binding links a Linux archive and the `justfile` uses Bash and Unix symbolic links.

Linux compilation, tests, and a headless startup have been checked. The Windows/WSLg instructions follow Microsoft's setup guidance but have not been tested on a Windows machine.

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

Clay is expected at `shared/clay`. Although `.gitmodules` names it, the current repository does not record a Git submodule entry, so clone it explicitly on a fresh checkout:

```sh
mkdir -p shared
git clone https://github.com/nicbarker/clay.git shared/clay
git -C shared/clay checkout e6cc36941ab2af5d81107617039d6f527a1c660b
```

Skip the clone if that directory already contains the Clay repository. The pinned revision matches the binding API used by this project.

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

## Markdown preview

Notes open in a formatted CommonMark preview. Use **Edit** in the toolbar to edit the Markdown source, and **Preview** to render the updated buffer. Preview supports headings, paragraphs, bold and italic text, lists, quotes, code blocks, rules, and styled link labels. The source buffer and per-note edits remain in memory when switching views.

The renderer uses Odin's `vendor:commonmark` binding, which links `libcmark` on Linux. Install it before building:

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
