package assets

import "core:fmt"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"

Icon :: enum {
	ChevronsUpDown,
	SquarePen,
	Search,
}

// Register new icons here; loading and cleanup are handled for every entry.
ICON_PATHS :: [Icon]cstring {
	.ChevronsUpDown = "assets/icons/chevrons-up-down.png",
	.SquarePen      = "assets/icons/square-pen.png",
	.Search         = "assets/icons/search.png",
}

Manager :: struct {
	textures: [Icon]^sdl.Texture,
}

load :: proc(renderer: ^sdl.Renderer) -> (manager: Manager, ok: bool) {
	for path, icon in ICON_PATHS {
		texture := img.LoadTexture(renderer, path)
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
	for texture in manager.textures {
		if texture != nil do sdl.DestroyTexture(texture)
	}
	manager^ = {}
}
