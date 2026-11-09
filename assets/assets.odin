package assets

import "core:fmt"
import "core:os"
import "core:strings"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"

Icon :: enum {
	ChevronsUpDown,
	SquarePen,
	Search,
	Slash,
	Link,
	List,
	ListOrdered,
	TextAlignStart,
	Underline,
	LetterB,
	ChevronDown,
	Redo,
	Undo,
	EllipsisVertical,
	Square,
	SquaresUnite,
	X,
}

// Register new icons here; loading and cleanup are handled for every entry.
ICON_PATHS :: [Icon]cstring {
	.ChevronsUpDown = "assets/icons/chevrons-up-down.png",
	.SquarePen      = "assets/icons/square-pen.png",
	.Search         = "assets/icons/search.png",
	.Slash          = "assets/icons/slash.png",
	.Link           = "assets/icons/link.png",
	.List           = "assets/icons/list.png",
	.ListOrdered    = "assets/icons/list-ordered.png",
	.TextAlignStart = "assets/icons/text-align-start.png",
	.Underline      = "assets/icons/underline.png",
	.LetterB        = "assets/icons/letter-b.png",
	.ChevronDown    = "assets/icons/chevron-down.png",
	.Redo           = "assets/icons/redo.png",
	.Undo           = "assets/icons/undo.png",
	.EllipsisVertical = "assets/icons/ellipsis-vertical.png",
	.Square = "assets/icons/square.png",
	.SquaresUnite = "assets/icons/squares-unite.png",
	.X = "assets/icons/x.png",
}

Manager :: struct {
	textures: [Icon]^sdl.Texture,
	app_icon: ^sdl.Texture,
}

// Packaged builds keep resources beside the executable. Development and Linux
// system installs also support their existing resource locations.
resource_path :: proc(path: string) -> cstring {
	if base := sdl.GetBasePath(); base != nil {
		bundled := fmt.tprintf("%s%s", base, path)
		if os.is_file(bundled) do return strings.clone_to_cstring(bundled, context.temp_allocator)
	}
	if os.is_file(path) do return strings.clone_to_cstring(path, context.temp_allocator)
	when ODIN_OS == .Linux {
		return strings.clone_to_cstring(fmt.tprintf("/usr/share/dope-notes/%s", path), context.temp_allocator)
	}
	return strings.clone_to_cstring(path, context.temp_allocator)
}

load :: proc(renderer: ^sdl.Renderer) -> (manager: Manager, ok: bool) {
	manager.app_icon = img.LoadTexture(renderer, resource_path("packaging/icons/dope-notes.png"))
	when ODIN_OS == .Linux {
		if manager.app_icon == nil do manager.app_icon = img.LoadTexture(renderer, "/usr/share/icons/hicolor/512x512/apps/dope-notes.png")
	}
	for path, icon in ICON_PATHS {
		texture := img.LoadTexture(renderer, resource_path(string(path)))
		if texture == nil {
			fmt.eprintln("Image load failed:", path, sdl.GetError())
			destroy(&manager)
			return manager, false
		}
		manager.textures[icon] = texture
		if !sdl.SetTextureScaleMode(texture, .LINEAR) {
			fmt.eprintln("Texture configuration failed:", path, sdl.GetError())
			destroy(&manager)
			return manager, false
		}
	}
	return manager, true
}

get :: proc(manager: ^Manager, icon: Icon) -> ^sdl.Texture {
	if manager == nil do return nil
	return manager.textures[icon]
}

destroy :: proc(manager: ^Manager) {
	if manager.app_icon != nil do sdl.DestroyTexture(manager.app_icon)
	for texture in manager.textures {
		if texture != nil do sdl.DestroyTexture(texture)
	}
	manager^ = {}
}
