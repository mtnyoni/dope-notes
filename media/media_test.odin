package media

import "core:fmt"
import "core:os"
import "core:testing"
import "core:strings"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"

@(test)
imported_images_are_portable_and_never_overwrite :: proc(t: ^testing.T) {
	assert(sdl.Init({}))
	defer sdl.Quit()
	root, err := os.make_directory_temp("", "dope-media-*", context.allocator)
	assert(err == nil)
	defer delete(root)
	defer os.remove_all(root)
	note := fmt.tprintf("%s/note.md", root)
	assert(os.write_entire_file(note, "") == nil)
	surface := sdl.CreateSurface(4, 3, .RGBA32)
	assert(surface != nil)
	defer sdl.DestroySurface(surface)
	first, ok := save_surface(note, surface)
	testing.expect(t, ok)
	testing.expect_value(t, first, "attachments/image-1.png")
	bytes, read_err := os.read_entire_file(fmt.tprintf("%s/%s", root, first), context.allocator)
	assert(read_err == nil)
	defer delete(bytes)
	second, bytes_ok := save_bytes(note, bytes)
	if !bytes_ok do fmt.eprintln("Image decode:", sdl.GetError(), "bytes:", len(bytes))
	testing.expect(t, bytes_ok)
	testing.expect_value(t, second, "attachments/image-2.png")
	third, file_ok := save_file(note, fmt.tprintf("%s/%s", root, second))
	testing.expect(t, file_ok)
	testing.expect_value(t, third, "attachments/image-3.png")
	_, bad := save_bytes(note, transmute([]u8)string("not an image"))
	testing.expect(t, !bad)
	loaded := img.Load(strings.clone_to_cstring(fmt.tprintf("%s/%s", root, third), context.temp_allocator))
	testing.expect(t, loaded != nil)
	if loaded != nil {
		testing.expect_value(t, loaded.w, 4)
		testing.expect_value(t, loaded.h, 3)
		sdl.DestroySurface(loaded)
	}
}
