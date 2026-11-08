package clay_ui

import "core:testing"
import clay "shared:clay"
import sdl "vendor:sdl3"

@(test)
clipping_intersects_only_enabled_axes :: proc(t: ^testing.T) {
	parent := sdl.Rect{10, 20, 100, 80}
	horizontal := intersect_clip(parent, {30, 0, 50, 5}, {horizontal = true})
	testing.expect_value(t, horizontal, sdl.Rect{30, 20, 50, 80})
	nested := intersect_clip(horizontal, {0, 40, 1000, 25}, {vertical = true})
	testing.expect_value(t, nested, sdl.Rect{30, 40, 50, 25})
	empty := intersect_clip(nested, {200, 0, 10, 100}, {horizontal = true})
	testing.expect_value(t, empty.w, i32(0))
}

@(test)
renderer_clips_pixels_and_restores_nested_state :: proc(t: ^testing.T) {
	surface := sdl.CreateSurface(32, 32, .RGBA32)
	testing.expect(t, surface != nil)
	if surface == nil do return
	defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(surface)
	testing.expect(t, renderer != nil)
	if renderer == nil do return
	defer sdl.DestroyRenderer(renderer)
	assert(sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255))
	assert(sdl.RenderClear(renderer))
	commands := [7]clay.RenderCommand {
		{commandType = .ScissorStart, boundingBox = {2, 0, 8, 16}, renderData = {clip = {horizontal = true}}},
		{commandType = .ScissorStart, boundingBox = {4, 4, 4, 4}, renderData = {clip = {horizontal = true, vertical = true}}},
		{commandType = .Rectangle, boundingBox = {0, 0, 16, 16}, renderData = {rectangle = {backgroundColor = {255, 0, 0, 255}}}},
		{commandType = .ScissorEnd},
		{commandType = .Rectangle, boundingBox = {0, 0, 16, 2}, renderData = {rectangle = {backgroundColor = {0, 255, 0, 255}}}},
		{commandType = .ScissorEnd},
		{commandType = .Rectangle, boundingBox = {14, 14, 1, 1}, renderData = {rectangle = {backgroundColor = {0, 0, 255, 255}}}},
	}
	array := clay.ClayArray(clay.RenderCommand){capacity = len(commands), length = len(commands), internalArray = raw_data(commands[:])}
	state: Clay_Renderer
	render_clay(&state, renderer, &array, 2, 2)
	testing.expect(t, !sdl.RenderClipEnabled(renderer))
	result := sdl.RenderReadPixels(renderer, nil)
	testing.expect(t, result != nil)
	if result == nil do return
	defer sdl.DestroySurface(result)
	r, g, b, a: u8
	assert(sdl.ReadSurfacePixel(result, 10, 10, &r, &g, &b, &a))
	testing.expect_value(t, r, u8(255)) // inside both nested clips
	assert(sdl.ReadSurfacePixel(result, 5, 10, &r, &g, &b, &a))
	testing.expect_value(t, r, u8(0)) // outside inner clip
	assert(sdl.ReadSurfacePixel(result, 5, 1, &r, &g, &b, &a))
	testing.expect_value(t, g, u8(255)) // outer clip restored
	assert(sdl.ReadSurfacePixel(result, 1, 1, &r, &g, &b, &a))
	testing.expect_value(t, g, u8(0)) // outer horizontal clip still enforced
	assert(sdl.ReadSurfacePixel(result, 28, 28, &r, &g, &b, &a))
	testing.expect_value(t, b, u8(255)) // no clip leaks to later UI
}

@(test)
floating_caret_stays_inside_inherited_viewport_clip :: proc(t: ^testing.T) {
	surface := sdl.CreateSurface(32, 32, .RGBA32)
	testing.expect(t, surface != nil)
	if surface == nil do return
	defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(surface)
	testing.expect(t, renderer != nil)
	if renderer == nil do return
	defer sdl.DestroyRenderer(renderer)
	assert(sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255))
	assert(sdl.RenderClear(renderer))
	// Clay emits the floating caret as a separate root: its inherited scissor
	// has bounds but no axis flags, unlike ordinary scroll-container scissors.
	commands := [3]clay.RenderCommand {
		{commandType = .ScissorStart, boundingBox = {4, 8, 16, 8}},
		{commandType = .Rectangle, boundingBox = {6, 4, 2, 12}, renderData = {rectangle = {backgroundColor = {255, 0, 0, 255}}}},
		{commandType = .ScissorEnd},
	}
	array := clay.ClayArray(clay.RenderCommand){capacity = len(commands), length = len(commands), internalArray = raw_data(commands[:])}
	state: Clay_Renderer
	render_clay(&state, renderer, &array, 1, 1)
	result := sdl.RenderReadPixels(renderer, nil)
	testing.expect(t, result != nil)
	if result == nil do return
	defer sdl.DestroySurface(result)
	r, g, b, a: u8
	assert(sdl.ReadSurfacePixel(result, 6, 5, &r, &g, &b, &a))
	testing.expect_value(t, r, u8(0)) // caret hidden above the document viewport
	assert(sdl.ReadSurfacePixel(result, 6, 10, &r, &g, &b, &a))
	testing.expect_value(t, r, u8(255)) // visible caret below the toolbar
	testing.expect(t, !sdl.RenderClipEnabled(renderer))
}
