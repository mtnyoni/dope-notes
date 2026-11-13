package markdown

import "core:fmt"
import theme "../theme"
import clay "shared:clay"
import commonmark "vendor:commonmark"

ImageResource :: struct {
	texture: rawptr,
	width, height: f32,
	loading: bool,
}
LoadImage :: #type proc(source, note_path: string, user_data: rawptr) -> ImageResource

prepare_image_rows :: proc(root: ^commonmark.Node, options: RenderOptions) -> map[int][dynamic]RenderBlock {
	result := make(map[int][dynamic]RenderBlock, context.temp_allocator)
	append_image_nodes(root, options, &result, false)
	return result
}

append_image_nodes :: proc(node: ^commonmark.Node, options: RenderOptions, rows: ^map[int][dynamic]RenderBlock, code: bool) {
	if node == nil do return
	kind := commonmark.node_get_type(node)
	if kind == .Code_Block || kind == .HTML_Block do return
	if kind == .Image {
		source := string(commonmark.node_get_url(node))
		alt_bytes := make([dynamic]u8, context.temp_allocator)
		image_alt(node, &alt_bytes)
		alt := string(alt_bytes[:])
		resource: ImageResource
		if options.load_image != nil do resource = options.load_image(source, options.note_path, options.image_user_data)
		width := min(options.width, resource.width)
		height: f32 = 40
		if resource.width > 0 && resource.height > 0 { height = resource.height*width/resource.width }
		block := RenderBlock{image = true, image_resource = resource, image_alt = alt, image_width = width, height = height+8, source_line = int(commonmark.node_get_start_line(node)), source_end_line = int(commonmark.node_get_end_line(node))}
		index := block.source_line-1
		list := rows^[index]
		if list == nil do list = make([dynamic]RenderBlock, context.temp_allocator)
		append(&list, block)
		rows^[index] = list
		return
	}
	for child := commonmark.node_first_child(node); child != nil; child = commonmark.node_next(child) do append_image_nodes(child, options, rows, code)
}

image_alt :: proc(node: ^commonmark.Node, bytes: ^[dynamic]u8) {
	if commonmark.node_get_type(node) == .Text do append(bytes, ..transmute([]u8)string(commonmark.node_get_literal(node)))
	for child := commonmark.node_first_child(node); child != nil; child = commonmark.node_next(child) do image_alt(child, bytes)
}

render_image :: proc(block: RenderBlock) {
	if block.image_resource.texture != nil {
		if clay.UI()({
			layout = {sizing = {width = clay.SizingFixed(block.image_width), height = clay.SizingFixed(block.height-8)}},
			image = {imageData = block.image_resource.texture},
		}) {}
	} else {
		label := block.image_resource.loading ? fmt.tprintf("Loading image: %s", block.image_alt) : fmt.tprintf("Image unavailable: %s", block.image_alt)
		clay.Text(label, {fontSize = 15, textColor = theme.Light.text_secondary})
	}
}
