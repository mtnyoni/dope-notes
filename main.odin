package main

import state "./state"
import assets "assets"
import "core:c"
import "core:fmt"
import "core:mem"
import font "font"
import markdown "markdown"
import buffer "buffer"
import clay "shared:clay"
import theme "theme"
import ui "ui"
import clay_ui "ui/clay"
import sdl "vendor:sdl3"

DEFAULT_WIN_W :: 1320
DEFAULT_WIN_H :: 640


main :: proc() {
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

	text_cursor := sdl.CreateSystemCursor(.TEXT)
	default_cursor := sdl.GetDefaultCursor()
	using_text_cursor := false

	defer {
		if text_cursor != nil {
			if default_cursor != nil {
				if !sdl.SetCursor(default_cursor) {
					fmt.eprintln("Could not restore default cursor:", sdl.GetError())
				}
			}
			sdl.DestroyCursor(text_cursor)
		}
	}

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

	ui_assets, assets_ok := assets.load(renderer)
	if !assets_ok do return
	defer assets.destroy(&ui_assets)

	assert(sdl.SetRenderLogicalPresentation(renderer, 0, 0, .DISABLED))
	clay_renderer := clay_ui.Clay_Renderer {
		font = face,
	}
	defer clay_ui.destroy_clay_renderer(&clay_renderer)

	notebooks, notebook_err := markdown.get_notes()
	if notebook_err != nil {
		fmt.eprintln("Could not load notebooks:", notebook_err)
		return
	}
	app_state := state.make_app_state(notebooks)
	defer markdown.free_notebooks(app_state.notebooks)

	documents: ui.EditorDocuments
	defer ui.editor_close_documents(&documents)
	empty_editor := ui.EditorState{buf = buffer.make_gap_buffer(64), face = face}
	defer ui.editor_destroy_state(&empty_editor)
	editor_state := &empty_editor
	if note := state.current_note(&app_state); note != nil {
		editor_state = ui.editor_open_note(&documents, note, face)
	}
	loaded_doc := app_state.current_doc

	if !sdl.StartTextInput(window) {
		fmt.eprintln("Could not start text input:", sdl.GetError())
		return
	}
	defer {
		if !sdl.StopTextInput(window) {
			fmt.eprintln("Could not stop text input:", sdl.GetError())
		}
	}


	vsync_enabled := sdl.SetRenderVSync(renderer, 1)
	previous_frame := sdl.GetTicksNS()
	running := true
	for running {
		defer free_all(context.temp_allocator)
		now := sdl.GetTicksNS()
		delta_seconds := clamp(f32(now - previous_frame) / 1e9, 0.001, 0.1)
		previous_frame = now
		e: sdl.Event
		scroll_delta: clay.Vector2
		left_pressed := false
		// input: ui.Input

		for sdl.PollEvent(&e) {
			ui.editor_handle_event(editor_state, &e)
			#partial switch e.type {
			case .MOUSE_WHEEL:
				direction: f32 = 1
				if e.wheel.direction == .FLIPPED do direction = -1
				scroll_delta.x += e.wheel.x * direction
				scroll_delta.y += e.wheel.y * direction
			case .QUIT:
				running = false
			case .MOUSE_BUTTON_DOWN:
				if e.button.button == sdl.BUTTON_LEFT {
					left_pressed = true
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
		assert(
			sdl.SetRenderDrawColor(
				renderer,
				u8(theme.Light.background.r),
				u8(theme.Light.background.g),
				u8(theme.Light.background.b),
				u8(theme.Light.background.a),
			),
		)
		assert(sdl.RenderClear(renderer))

		mouse_x, mouse_y: f32
		mouse_buttons := sdl.GetMouseState(&mouse_x, &mouse_y)
		clay.SetLayoutDimensions({f32(width), f32(height)})
		clay.SetPointerState({mouse_x, mouse_y}, .LEFT in mouse_buttons)
		if text_cursor != nil && default_cursor != nil {
			over_editor := sdl.GetMouseFocus() == window && clay.PointerOver(clay.ID(ui.EDITOR_ID))
			if over_editor != using_text_cursor {
				cursor := over_editor ? text_cursor : default_cursor
				if sdl.SetCursor(cursor) {
					using_text_cursor = over_editor
				} else {
					fmt.eprintln("Could not change mouse cursor:", sdl.GetError())
				}
			}
		}

		if app_state.current_doc != loaded_doc {
			selected_note := state.current_note(&app_state)
			if selected_note != nil {
				editor_state = ui.editor_open_note(&documents, selected_note, face)
				loaded_doc = selected_note.path
			} else if app_state.current_doc == "" {
				editor_state = &empty_editor
				loaded_doc = ""
			} else {
				fmt.eprintln("Note not found:", app_state.current_doc)
				app_state.current_doc = loaded_doc
			}
		}

		clay.UpdateScrollContainers(false, {}, delta_seconds)
		clay.BeginLayout()
		ui.UILayout(
			&ui_assets,
			&app_state,
			editor_state,
			{
				wheel_y = scroll_delta.y,
				mouse = {mouse_x, mouse_y},
				left_down = .LEFT in mouse_buttons,
				left_pressed = left_pressed,
				pointer_in_window = sdl.GetMouseFocus() == window,
			},
			delta_seconds,
		)
		commands := clay.EndLayout(delta_seconds)
		clay_ui.render_clay(&clay_renderer, renderer, &commands, scale_x, scale_y)

		assert(sdl.RenderPresent(renderer))
		if !vsync_enabled do sdl.Delay(16)
	}
}
