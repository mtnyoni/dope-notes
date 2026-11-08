package markdown

import "core:testing"
import theme "../theme"
import "core:unicode/utf8"
import clay "shared:clay"
import commonmark "vendor:commonmark"

render_test_measure :: proc "c" (text: clay.StringSlice, config: ^clay.TextElementConfig, user_data: rawptr) -> clay.Dimensions {
	count := 0
	for _ in string(text.chars[:text.length]) do count += 1
	return {f32(count) * 7, f32(config.fontSize)}
}

@(test)
commonmark_layout_preserves_block_and_inline_semantics :: proc(t: ^testing.T) {
	source := "# Heading\n\nPlain **bold** and *italic* with [a link](https://example.com) and `code`.\n\n- First\n- Second\n\n3. Third\n4. Fourth\n\n> Quoted text\n\n```odin\nhello()\n  world()\n```\n\n---\n"
	root := commonmark.parse_document_from_string(source, {})
	testing.expect(t, root != nil)
	if root == nil do return
	defer commonmark.node_free(root)
	layout := prepare_markdown_layout(root, {width = 300, measure = render_test_measure})
	testing.expect(t, len(layout.blocks) >= 9)
	if len(layout.blocks) == 0 do return
	testing.expect_value(t, layout.blocks[0].font_size, u16(30))
	bold, italic, code, quote, rule, bullet, ordered, link := false, false, false, false, false, false, false, false
	height: f32
	for block in layout.blocks {
		height += block.height
		code = code || block.code
		quote = quote || block.quote
		rule = rule || block.rule
		bullet = bullet || block.marker == "•"
		ordered = ordered || block.marker == "3."
		for line in block.lines {
			for span in line.spans {
				bold = bold || (span.text == "bold" && span.style & 1 != 0)
				italic = italic || (span.text == "italic" && span.style & 2 != 0)
				link = link || span.color == theme.Cyan_700
				testing.expect(t, span.text != "**" && span.text != "#")
			}
		}
	}
	testing.expect(t, bold && italic && code && quote && rule && bullet && ordered && link)
	testing.expect_value(t, layout.height, height)
}

@(test)
markdown_wraps_long_unicode_tokens_at_character_boundaries :: proc(t: ^testing.T) {
	root := commonmark.parse_document_from_string("éééé", {})
	defer commonmark.node_free(root)
	layout := prepare_markdown_layout(root, {width = 20, measure = render_test_measure})
	testing.expect_value(t, len(layout.blocks), 1)
	if len(layout.blocks) != 1 do return
	testing.expect_value(t, len(layout.blocks[0].lines), 2)
	for line in layout.blocks[0].lines {
		for span in line.spans {
			testing.expect(t, utf8.valid_string(span.text))
			testing.expect(t, span_width(span, 15, {measure = render_test_measure}) <= 20)
		}
	}
}
