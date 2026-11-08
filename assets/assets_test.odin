package assets

import "core:testing"
import sdl "vendor:sdl3"

@(test)
load_registered_icons_and_release_them :: proc(t: ^testing.T) {
	surface := sdl.CreateSurface(32, 32, .RGBA32)
	testing.expect(t, surface != nil)
	if surface == nil do return
	defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(surface)
	testing.expect(t, renderer != nil)
	if renderer == nil do return
	defer sdl.DestroyRenderer(renderer)

	manager, ok := load(renderer)
	testing.expect(t, ok)
	if !ok do return
	defer destroy(&manager)
	for _, icon in ICON_PATHS {
		texture := get(&manager, icon)
		testing.expect(t, texture != nil)
		width, height: f32
		testing.expect(t, sdl.GetTextureSize(texture, &width, &height))
		testing.expect(t, width > 0 && height > 0)
	}
	destroy(&manager)
	for _, icon in ICON_PATHS do testing.expect(t, get(&manager, icon) == nil)
}
