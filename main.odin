package main

import config "./appconfig"
import state "./state"
import media "./media"
import assets "assets"
import buffer "buffer"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import font "font"
import markdown "markdown"
import clay "shared:clay"
import theme "theme"
import ui "ui"
import clay_ui "ui/clay"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"

DEFAULT_WIN_W :: 1320
DEFAULT_WIN_H :: 640

Save_Ticker :: struct {
	mutex:   ^sdl.Mutex,
	running: bool,
	pending: bool,
}

save_tick :: proc "c" (data: rawptr) -> c.int {
	ticker := cast(^Save_Ticker)data
	for {
		sdl.Delay(1000)
		sdl.LockMutex(ticker.mutex)
		if !ticker.running {
			sdl.UnlockMutex(ticker.mutex)
			break
		}
		ticker.pending = true
		sdl.UnlockMutex(ticker.mutex)
	}
	return 0
}

save_focused_note :: proc(ed: ^ui.EditorState, path: string, last_saved: ^string) {
	if path == "" || ed == nil do return
	left, right := buffer.get_strings(&ed.buf)
	content := fmt.tprintf("%s%s", left, right)
	if content == last_saved^ do return
	if err := os.write_entire_file(path, content); err != nil {
		fmt.eprintln("Could not save note:", path, err)
		return
	}
	delete(last_saved^)
	last_saved^ = strings.clone(content)
}


main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer mem.tracking_allocator_destroy(&track)

	_ = sdl.SetAppMetadata(config.WINDOW_TITLE, config.VERSION, config.APPLICATION_ID)
	if !sdl.Init(sdl.INIT_VIDEO) {
		fmt.eprintln("SDL init failed:", sdl.GetError())
		return
	}
	defer sdl.Quit()

	window := sdl.CreateWindow(
		config.WINDOW_TITLE,
		DEFAULT_WIN_W,
		DEFAULT_WIN_H,
		{.RESIZABLE, .HIGH_PIXEL_DENSITY, .BORDERLESS, .TRANSPARENT},
	)
	assert(window != nil)
	defer sdl.DestroyWindow(window)
	sdl.SetWindowHitTest(window, ui.window_hit_test, nil)

	icon := img.Load(assets.resource_path("packaging/icons/dope-notes.png"))
	when ODIN_OS == .Linux {
		if icon == nil do icon = img.Load("/usr/share/icons/hicolor/512x512/apps/dope-notes.png")
	}
	if icon != nil {
		_ = sdl.SetWindowIcon(window, icon)
		sdl.DestroySurface(icon)
	}

	text_cursor := sdl.CreateSystemCursor(.TEXT)
	resize_nwse := sdl.CreateSystemCursor(.NWSE_RESIZE)
	resize_nesw := sdl.CreateSystemCursor(.NESW_RESIZE)
	resize_ew := sdl.CreateSystemCursor(.EW_RESIZE)
	resize_ns := sdl.CreateSystemCursor(.NS_RESIZE)
	default_cursor := sdl.GetDefaultCursor()
	active_cursor := default_cursor
	defer {
		if default_cursor != nil do _ = sdl.SetCursor(default_cursor)
		if text_cursor != nil do sdl.DestroyCursor(text_cursor)
		if resize_nwse != nil do sdl.DestroyCursor(resize_nwse)
		if resize_nesw != nil do sdl.DestroyCursor(resize_nesw)
		if resize_ew != nil do sdl.DestroyCursor(resize_ew)
		if resize_ns != nil do sdl.DestroyCursor(resize_ns)
	}

	width, height: i32
	assert(sdl.GetWindowSize(window, &width, &height))
	minMemorySize: c.size_t = cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	clayArena := clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(clayArena, {f32(width), f32(height)}, {handler = clay_ui.errorHandler})

	face := font.open(assets.resource_path("font/Roboto-Regular.ttf"))
	if face == nil {
		fmt.eprintln("Could not load Dope Notes font")
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
	image_media: media.Manager
	if !media.init(&image_media, renderer) { fmt.eprintln("Could not initialize image loading"); return }
	defer media.destroy(&image_media)

	ui_assets, assets_ok := assets.load(renderer)
	if !assets_ok do return
	defer assets.destroy(&ui_assets)

	assert(sdl.SetRenderLogicalPresentation(renderer, 0, 0, .DISABLED))
	clay_renderer := clay_ui.Clay_Renderer {
		font = face,
	}
	defer clay_ui.destroy_clay_renderer(&clay_renderer)

	data_home := os.get_env("XDG_DATA_HOME", context.temp_allocator)
	when ODIN_OS == .Windows {
		data_home = os.get_env("APPDATA", context.temp_allocator)
	}
	if data_home == "" {
		home := os.get_env("HOME", context.temp_allocator)
		when ODIN_OS == .Windows {
			home = os.get_env("USERPROFILE", context.temp_allocator)
		}
		if home == "" {
			fmt.eprintln("Cannot find user notes storage")
			return
		}
		when ODIN_OS == .Windows {
			data_home = fmt.tprintf("%s/AppData/Roaming", home)
		} else {
			data_home = fmt.tprintf("%s/.local/share", home)
		}
	}
	notes_dir := config.notebooks_path(data_home)
	first_run := !os.exists(notes_dir)
	default_notebook := fmt.tprintf("%s/Default", notes_dir)
	if first_run {
		if err := os.make_directory_all(default_notebook); err != nil {
			fmt.eprintln("Could not create notes directory:", err)
			return
		}
		if err := os.write_entire_file(
			fmt.tprintf("%s/Welcome.md", default_notebook),
			"Hello there!\n",
		); err != nil {
			fmt.eprintln("Could not create welcome note:", err)
			return
		}
	}
	notebooks, notebook_err := markdown.get_notes(notes_dir)
	if notebook_err != nil {
		fmt.eprintln("Could not load notebooks:", notebook_err)
		return
	}
	if err := markdown.migrate_note_folders(notebooks[:]); err != nil {
		fmt.eprintln("Could not migrate note storage:", err)
		markdown.free_notebooks(notebooks)
		return
	}
	app_state := state.make_app_state(notebooks, "Default")
	defer markdown.free_notebooks(app_state.notebooks)

	documents: ui.EditorDocuments
	defer ui.editor_close_documents(&documents)
	empty_editor := ui.EditorState {
		buf  = buffer.make_gap_buffer(64),
		font = face,
	}
	defer ui.editor_destroy_state(&empty_editor)
	editor_state := &empty_editor
	if note := state.current_note(&app_state); note != nil {
		editor_state = ui.editor_open_note(&documents, note, face)
	}
	loaded_doc := app_state.current_doc
	last_saved := ""
	if note := state.current_note(&app_state); note != nil do last_saved = strings.clone(string(note.content))
	defer delete(last_saved)
	ticker := Save_Ticker {
		mutex   = sdl.CreateMutex(),
		running = true,
	}
	assert(ticker.mutex != nil)
	defer sdl.DestroyMutex(ticker.mutex)
	thread := sdl.CreateThread(save_tick, "note-save-ticker", &ticker)
	assert(thread != nil)
	defer {
		sdl.LockMutex(ticker.mutex)
		ticker.running = false
		sdl.UnlockMutex(ticker.mutex)
		sdl.WaitThread(thread, nil)
		save_focused_note(editor_state, loaded_doc, &last_saved)
	}

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
		sync_requested := false
		sdl.LockMutex(ticker.mutex)
		save_due := ticker.pending
		ticker.pending = false
		sdl.UnlockMutex(ticker.mutex)
		if save_due do save_focused_note(editor_state, loaded_doc, &last_saved)
		now := sdl.GetTicksNS()
		delta_seconds := clamp(f32(now - previous_frame) / 1e9, 0.001, 0.1)
		previous_frame = now
		e: sdl.Event
		scroll_delta: clay.Vector2
		left_pressed := false
		// input: ui.Input

		for sdl.PollEvent(&e) {
			if e.type == .KEY_DOWN &&
			   e.key.key == sdl.K_G &&
			   sdl.KMOD_CTRL & e.key.mod != {} &&
			   sdl.KMOD_SHIFT & e.key.mod != {} {
				sync_requested = true
				continue
			}
			editor_state.media = &image_media
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
		if sync_requested {
			save_focused_note(editor_state, loaded_doc, &last_saved)
			if config.sync_github(notes_dir) {
				fresh_notebooks, fresh_err := markdown.get_notes(notes_dir)
				if fresh_err == nil {
					ui.editor_close_documents(&documents)
					markdown.free_notebooks(app_state.notebooks)
					app_state = state.make_app_state(fresh_notebooks, "Default")
					editor_state = &empty_editor
					loaded_doc = ""
					delete(last_saved)
					last_saved = ""
					if note := state.current_note(&app_state); note != nil {
						editor_state = ui.editor_open_note(&documents, note, face)
						loaded_doc = note.path
						last_saved = strings.clone(string(note.content))
					}
				}
				fmt.println("GitHub sync complete")
			} else {
				fmt.eprintln("GitHub sync failed; see details above")
			}
		}
		state.update_note_content(&app_state, loaded_doc, ui.editor_text(editor_state))
		if app_state.new_note_requested {
			app_state.new_note_requested = false
			if err := state.create_note(&app_state); err != nil {
				fmt.eprintln("Could not create note:", err)
			}
		}

		width, height: i32
		assert(sdl.GetWindowSize(window, &width, &height))
		output_width, output_height: i32
		assert(sdl.GetRenderOutputSize(renderer, &output_width, &output_height))
		scale_x := f32(output_width) / f32(width)
		scale_y := f32(output_height) / f32(height)
		assert(sdl.SetRenderDrawColor(renderer, 0, 0, 0, 0))
		assert(sdl.RenderClear(renderer))

		mouse_x, mouse_y: f32
		mouse_buttons := sdl.GetMouseState(&mouse_x, &mouse_y)
		clay.SetLayoutDimensions({f32(width), f32(height)})
		clay.SetPointerState({mouse_x, mouse_y}, .LEFT in mouse_buttons)
		if default_cursor != nil {
			cursor := default_cursor
			if sdl.GetMouseFocus() == window {
				point := sdl.Point{i32(mouse_x), i32(mouse_y)}
				hit := ui.titlebar_hit_test(window, &point)
				#partial switch hit {
				case .RESIZE_TOPLEFT, .RESIZE_BOTTOMRIGHT:
					cursor = resize_nwse
				case .RESIZE_TOPRIGHT, .RESIZE_BOTTOMLEFT:
					cursor = resize_nesw
				case .RESIZE_LEFT, .RESIZE_RIGHT:
					cursor = resize_ew
				case .RESIZE_TOP, .RESIZE_BOTTOM:
					cursor = resize_ns
				case:
					if clay.PointerOver(clay.ID(ui.EDITOR_ID)) do cursor = text_cursor
				}
			}
			if cursor == nil do cursor = default_cursor
			if cursor != active_cursor && sdl.SetCursor(cursor) do active_cursor = cursor
		}

		if app_state.current_doc != loaded_doc {
			save_focused_note(editor_state, loaded_doc, &last_saved)
			selected_note := state.current_note(&app_state)
			if selected_note != nil {
				editor_state = ui.editor_open_note(&documents, selected_note, face)
				loaded_doc = selected_note.path
				delete(last_saved)
				last_saved = strings.clone(string(selected_note.content))
			} else if app_state.current_doc == "" {
				editor_state = &empty_editor
				loaded_doc = ""
			} else {
				fmt.eprintln("Note not found:", app_state.current_doc)
				app_state.current_doc = loaded_doc
			}
		}

		editor_state.media = &image_media
		clay.UpdateScrollContainers(
			false,
			{scroll_delta.x * 7.2, scroll_delta.y * 7.2},
			delta_seconds,
		)
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
			window,
		)
		commands := clay.EndLayout(delta_seconds)
		clay_ui.render_clay(&clay_renderer, renderer, &commands, scale_x, scale_y)

		assert(sdl.RenderPresent(renderer))
		if !vsync_enabled do sdl.Delay(16)
	}
}
