package font

import "core:c"

Font :: struct {}

when ODIN_OS == .Windows {
	foreign import font_lib {"font.lib", "system:freetype"}
} else {
	foreign import font_lib {"font.a", "system:freetype"}
}

@(default_calling_convention = "c", link_prefix = "app_font_")
foreign font_lib {
	open :: proc(path: cstring) -> ^Font ---
	close :: proc(font: ^Font) ---
	measure :: proc(font: ^Font, text: [^]u8, length, pixel_size: c.int, width, height: ^c.int) -> c.int ---
	rasterize :: proc(font: ^Font, text: [^]u8, length, pixel_size: c.int, pixels: ^^u8, width, height: ^c.int) -> c.int ---
	measure_styled :: proc(font: ^Font, text: [^]u8, length, pixel_size, style: c.int, width, height: ^c.int) -> c.int ---
	rasterize_styled :: proc(font: ^Font, text: [^]u8, length, pixel_size, style: c.int, pixels: ^^u8, width, height: ^c.int) -> c.int ---
	free_bitmap :: proc(pixels: ^u8) ---
}
