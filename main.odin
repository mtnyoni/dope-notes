package main

import "buffer"
import "core:c"
import "core:fmt"
import "core:mem"
import font "font"
import clay "shared:clay"
import ui "ui"
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
		"dope-notes",
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

	face := font.open("font/Roboto-Regular.ttf")
	if face == nil {
		fmt.eprintln("Could not load ui/font/Roboto-Regular.ttf")
		return
	}
	defer font.close(face)
	clay.SetMeasureTextFunction(clay_ui.measure_text, face)

	renderer := sdl.CreateRenderer(window, nil)
	if renderer == nil {
		fmt.eprintln("Renderer creation failed:", sdl.GetError())
		return
	}
	defer sdl.DestroyRenderer(renderer)
	assert(sdl.SetRenderLogicalPresentation(renderer, 0, 0, .DISABLED))
	clay_renderer := clay_ui.Clay_Renderer {
		font = face,
	}
	defer clay_ui.destroy_clay_renderer(&clay_renderer)

	running := true
	for running {
		defer free_all(context.temp_allocator)
		e: sdl.Event
		// input: ui.Input

		for sdl.PollEvent(&e) {
			#partial switch e.type {
			case .QUIT:
				running = false
			case .MOUSE_BUTTON_DOWN:
				if e.button.button == sdl.BUTTON_LEFT {
					// input.left_pressed = true
				}
			case .MOUSE_BUTTON_UP:
				if e.button.button == sdl.BUTTON_LEFT {
					// input.left_released = true
				}
			}
		}

		width, height: i32
		assert(sdl.GetWindowSize(window, &width, &height))
		output_width, output_height: i32
		assert(sdl.GetRenderOutputSize(renderer, &output_width, &output_height))
		scale_x := f32(output_width) / f32(width)
		scale_y := f32(output_height) / f32(height)
		assert(sdl.SetRenderDrawColor(renderer, 255, 255, 255, 255))
		assert(sdl.RenderClear(renderer))

		mouse_x, mouse_y: f32
		mouse_buttons := sdl.GetMouseState(&mouse_x, &mouse_y)
		// input.left_down = .LEFT in mouse_buttons
		// clay.SetPointerState({mouse_x, mouse_y}, input.left_down)
		clay.SetLayoutDimensions({f32(width), f32(height)})

		clay.BeginLayout()
		// login_clicked := ui.Login_Form(eye_icon, input, &login_state)
		ui.UILayout()
		commands := clay.EndLayout(1.0 / 60.0)

		// if login_clicked {
		// 	handle_back()
		// }

		clay_ui.render_clay(&clay_renderer, renderer, &commands, scale_x, scale_y)

		assert(sdl.RenderPresent(renderer))
		sdl.Delay(16)
	}
}
