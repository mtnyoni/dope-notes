package markdown

import "core:testing"
import commonmark "vendor:commonmark"

image_test_loader :: proc(source, path: string, data: rawptr) -> ImageResource {
	return {texture = rawptr(uintptr(1)), width = 800, height = 400}
}

@(test)
images_render_with_alt_and_proportional_size :: proc(t: ^testing.T) {
	text := "![Alt text for the image](https://example.com/image.jpg)"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	layout := prepare_live_markdown_layout(root, {width = 400, load_image = image_test_loader}, text, 0)
	testing.expect_value(t, len(layout.blocks), 1)
	if len(layout.blocks) != 1 do return
	block := layout.blocks[0]
	testing.expect(t, block.image && !block.active)
	testing.expect_value(t, block.image_alt, "Alt text for the image")
	testing.expect_value(t, block.image_width, f32(400))
	testing.expect_value(t, block.height, f32(208))
}

@(test)
images_in_code_stay_literal_and_unavailable_images_keep_alt :: proc(t: ^testing.T) {
	text := "```\n![code](attachments/missing.png)\n```\n\n![Missing](attachments/missing.png)"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	layout := prepare_live_markdown_layout(root, {width = 400}, text, -1)
	count := 0
	for block in layout.blocks {
		if !block.image do continue
		count += 1
		testing.expect_value(t, block.image_alt, "Missing")
		testing.expect(t, block.image_resource.texture == nil)
	}
	testing.expect_value(t, count, 1)
}
