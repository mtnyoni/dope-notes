package media

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import markdown "../markdown"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"
import curl "vendor:curl"

Manager :: struct {
	renderer: ^sdl.Renderer,
	entries: map[string]^Entry,
}
Entry :: struct {
	texture: ^sdl.Texture,
	width, height: f32,
	failed: bool,
	job: ^Download,
}
Download :: struct {
	url, path: string,
	mutex: ^sdl.Mutex,
	thread: ^sdl.Thread,
	done, ok: bool,
}
DownloadBuffer :: struct { bytes: [dynamic]u8 }
MAX_IMAGE_BYTES :: 32*1024*1024

init :: proc(manager: ^Manager, renderer: ^sdl.Renderer) -> bool {
	manager.renderer = renderer
	manager.entries = make(map[string]^Entry)
	return curl.global_init(curl.GLOBAL_DEFAULT) == .OK
}

destroy :: proc(manager: ^Manager) {
	for key, entry in manager.entries {
		if entry.job != nil {
			sdl.WaitThread(entry.job.thread, nil)
			sdl.DestroyMutex(entry.job.mutex)
			delete(entry.job.url)
			delete(entry.job.path)
			free(entry.job)
		}
		if entry.texture != nil do sdl.DestroyTexture(entry.texture)
		delete(key)
		free(entry)
	}
	delete(manager.entries)
	curl.global_cleanup()
}

// SDL textures are created on the UI thread; network I/O runs in a worker.
load_image :: proc(source, note_path: string, user_data: rawptr) -> markdown.ImageResource {
	manager := cast(^Manager)user_data
	if manager == nil do return {}
	remote := strings.has_prefix(source, "https://") || strings.has_prefix(source, "http://")
	path := source
	if remote {
		if note_path == "" do return {}
		hash: u64 = 14695981039346656037
		for byte in transmute([]u8)source { hash = (hash ~ u64(byte))*1099511628211 }
		path = fmt.tprintf("%s/attachments/remote-%016x.img", os.dir(note_path), hash)
	} else if !os.is_abs(path) {
		if note_path == "" do return {}
		path = fmt.tprintf("%s/%s", os.dir(note_path), source)
	}
	entry, found := manager.entries[path]
	if !found {
		entry = new(Entry)
		manager.entries[strings.clone(path)] = entry
		if remote && !os.exists(path) {
			if err := os.make_directory_all(os.dir(path)); err != nil { entry.failed = true; return {} }
			job := new(Download)
			job.url = strings.clone(source)
			job.path = strings.clone(path)
			job.mutex = sdl.CreateMutex()
			if job.mutex == nil { delete(job.url); delete(job.path); free(job); entry.failed = true; return {} }
			job.thread = sdl.CreateThread(download_image, "image-download", job)
			if job.thread == nil { sdl.DestroyMutex(job.mutex); delete(job.url); delete(job.path); free(job); entry.failed = true; return {} }
			entry.job = job
		}
	}
	if entry.job != nil {
		sdl.LockMutex(entry.job.mutex)
		done, ok := entry.job.done, entry.job.ok
		sdl.UnlockMutex(entry.job.mutex)
		if !done do return markdown.ImageResource{loading = true}
		if !ok do entry.failed = true
	}
	if !entry.failed && entry.texture == nil {
		entry.texture = img.LoadTexture(manager.renderer, strings.clone_to_cstring(path, context.temp_allocator))
		if entry.texture == nil {
			entry.failed = true
			fmt.eprintln("Could not load image:", path, sdl.GetError())
		} else {
			_ = sdl.GetTextureSize(entry.texture, &entry.width, &entry.height)
			_ = sdl.SetTextureScaleMode(entry.texture, .LINEAR)
		}
	}
	return markdown.ImageResource{texture = entry.texture, width = entry.width, height = entry.height}
}

save_file :: proc(note_path, source: string) -> (relative: string, ok: bool) {
	surface := img.Load(strings.clone_to_cstring(source, context.temp_allocator))
	if surface == nil do return
	defer sdl.DestroySurface(surface)
	return save_surface(note_path, surface)
}

save_bytes :: proc(note_path: string, bytes: []u8) -> (relative: string, ok: bool) {
	if len(bytes) == 0 || len(bytes) > MAX_IMAGE_BYTES do return
	stream := sdl.IOFromConstMem(raw_data(bytes), uint(len(bytes)))
	if stream == nil do return
	surface := img.Load_IO(stream, true)
	if surface == nil do return
	defer sdl.DestroySurface(surface)
	return save_surface(note_path, surface)
}

save_surface :: proc(note_path: string, surface: ^sdl.Surface) -> (relative: string, ok: bool) {
	if note_path == "" do return
	directory := fmt.tprintf("%s/attachments", os.dir(note_path))
	if err := os.make_directory_all(directory); err != nil do return
	index := 1
	path := ""
	for {
		relative = fmt.tprintf("attachments/image-%d.png", index)
		path = fmt.tprintf("%s/%s", os.dir(note_path), relative)
		if !os.exists(path) do break
		index += 1
	}
	ok = img.SavePNG(surface, strings.clone_to_cstring(path, context.temp_allocator))
	return
}

receive_image :: proc "c" (data: rawptr, size, count: uint, user_data: rawptr) -> uint {
	context = runtime.default_context()
	buffer := cast(^DownloadBuffer)user_data
	if count > MAX_IMAGE_BYTES || size > MAX_IMAGE_BYTES || size*count > MAX_IMAGE_BYTES-uint(len(buffer.bytes)) do return 0
	length := size*count
	append(&buffer.bytes, (cast([^]u8)data)[:length]...)
	return length
}

download_image :: proc "c" (data: rawptr) -> c.int {
	context = runtime.default_context()
	job := cast(^Download)data
	buffer := DownloadBuffer{bytes = make([dynamic]u8)}
	defer delete(buffer.bytes)
	ok := false
	handle := curl.easy_init()
	if handle != nil {
		_ = curl.easy_setopt(handle, .URL, strings.clone_to_cstring(job.url, context.temp_allocator))
		_ = curl.easy_setopt(handle, .PROTOCOLS_STR, cstring("http,https"))
		_ = curl.easy_setopt(handle, .REDIR_PROTOCOLS_STR, cstring("http,https"))
		_ = curl.easy_setopt(handle, .FOLLOWLOCATION, c.long(1))
		_ = curl.easy_setopt(handle, .MAXREDIRS, c.long(5))
		_ = curl.easy_setopt(handle, .FAILONERROR, c.long(1))
		_ = curl.easy_setopt(handle, .NOSIGNAL, c.long(1))
		_ = curl.easy_setopt(handle, .TIMEOUT_MS, c.long(8000))
		_ = curl.easy_setopt(handle, .WRITEFUNCTION, receive_image)
		_ = curl.easy_setopt(handle, .WRITEDATA, &buffer)
		if curl.easy_perform(handle) == .OK && len(buffer.bytes) > 0 {
			partial := fmt.tprintf("%s.part", job.path)
			if os.write_entire_file(partial, buffer.bytes[:]) == nil {
				ok = os.rename(partial, job.path) == nil
				if !ok do _ = os.remove(partial)
			}
		}
		curl.easy_cleanup(handle)
	}
	free_all(context.temp_allocator)
	sdl.LockMutex(job.mutex)
	job.ok = ok
	job.done = true
	sdl.UnlockMutex(job.mutex)
	return 0
}
