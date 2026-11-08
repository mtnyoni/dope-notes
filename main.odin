package main

import "buffer"
import "core:c"
import "core:fmt"
import "core:mem"
import clay "shared:clay"
import clay_ui "ui/clay"
import sdl "vendor:sdl3"

DEFAULT_WIN_W :: 1080
DEFAULT_WIN_H :: 640

main :: proc() {
	buf := buffer.make_gap_buffer(2)
	defer buffer.destroy_gap_buffer(&buf)

	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer mem.tracking_allocator_destroy(&track)

	if !sdl.Init(sdl.INIT_VIDEO) {
		fmt.eprintln("SDL init failed:", sdl.GetError())
		return
	}
	defer sdl.Quit()

	window := sdl.CreateWindow(
		"SDL_Image",
		DEFAULT_WIN_W,
		DEFAULT_WIN_H,
		{.RESIZABLE, .HIGH_PIXEL_DENSITY},
	)
	assert(window != nil)
	defer sdl.DestroyWindow(window)

	width, height: i32
	assert(sdl.GetWindowSize(window, &width, &height))
	minMemorySize: c.size_t = cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	clayArena := clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(clayArena, {f32(width), f32(height)}, {handler = clay_ui.errorHandler})
}
