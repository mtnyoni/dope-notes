package markdown

import "core:testing"
import "core:fmt"
import "core:unicode/utf8"
import commonmark "vendor:commonmark"

@(test)
only_the_active_physical_line_exposes_markdown_source :: proc(t: ^testing.T) {
	text := "# Heading\n\nFirst **bold** line\nsecond *italic* line\n\n```odin\ncode_one()\ncode_two()\n```\n"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	options := RenderOptions{width = 300, measure = render_test_measure}
	layout := prepare_live_markdown_layout(root, options, text, 2)
	active := 0
	italic := false
	for block in layout.blocks {
		if block.active {
			active += 1
			testing.expect_value(t, block.source_line, 3)
			testing.expect_value(t, block.lines[0].spans[0].text, "First **bold** line")
		}
		for line in block.lines {
			for span in line.spans do italic = italic || (span.text == "italic" && span.style & 2 != 0)
		}
	}
	testing.expect_value(t, active, 1)
	testing.expect_value(t, layout.blocks[0].font_size, u16(30))
	testing.expect(t, italic)

	// Editing a fenced code line must not turn the rest into paragraphs.
	layout = prepare_live_markdown_layout(root, options, text, 6)
	code_preserved := false
	for block in layout.blocks {
		if block.source_line == 8 {
			testing.expect(t, block.code && !block.active)
			code_preserved = true
		}
	}
	testing.expect(t, code_preserved)
	// A blank line can receive the cursor even though it has no AST node.
	layout = prepare_live_markdown_layout(root, options, text, 1)
	active = 0
	for block in layout.blocks {
		if block.active {
			active += 1
			testing.expect_value(t, block.lines[0].spans[0].text, "")
		}
	}
	testing.expect_value(t, active, 1)
}

@(test)
active_source_wraps_without_splitting_utf8 :: proc(t: ^testing.T) {
	text := "# éééééé"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	layout := prepare_live_markdown_layout(root, {width = 20, measure = render_test_measure}, text, 0)
	testing.expect_value(t, len(layout.blocks), 1)
	testing.expect(t, len(layout.blocks[0].lines) > 1)
	for row in layout.blocks[0].lines {
		testing.expect(t, utf8.valid_string(row.spans[0].text))
		testing.expect_value(t, text[row.source_start:row.source_end], row.spans[0].text)
	}
}

@(test)
active_source_wraps_at_words_without_adding_source_lines :: proc(t: ^testing.T) {
	text := "hello world again"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	layout := prepare_live_markdown_layout(root, {width = 70, measure = render_test_measure}, text, 0)
	testing.expect_value(t, len(layout.blocks), 1)
	for line in layout.blocks[0].lines {
		if line.source_end < len(text) {
			testing.expect(t, line.source_end == 6 || line.source_end == 12)
		}
	}
}

@(test)
list_code_fences_and_setext_spacing_keep_their_context :: proc(t: ^testing.T) {
	text := "- ```odin\n  first()\n  second()\n  ```\n"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	layout := prepare_live_markdown_layout(root, {width = 300, measure = render_test_measure}, text, 2)
	code_found, active_found := false, false
	for block in layout.blocks {
		if block.code {
			code_found = true
			testing.expect_value(t, block.marker, "•")
			testing.expect_value(t, block.lines[0].spans[0].text, "first()")
		}
		if block.active {
			active_found = true
			testing.expect_value(t, block.lines[0].spans[0].text, "  second()")
		}
	}
	testing.expect(t, code_found && active_found)

	setext := "Title\n=====\n\nParagraph."
	other := commonmark.parse_document_from_string(setext, {})
	defer commonmark.node_free(other)
	layout = prepare_live_markdown_layout(other, {width = 300, measure = render_test_measure}, setext, 3)
	testing.expect_value(t, layout.blocks[0].spacing, f32(12))
	testing.expect_value(t, layout.blocks[0].font_size, u16(30))
}

@(test)
selection_highlights_only_selected_visible_text :: proc(t: ^testing.T) {
	text := "One éé word\nSecond **bold** line"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	directions := [2]bool{false, true}
	for reversed in directions {
		options := RenderOptions{width = 75, measure = render_test_measure, selection_start = 4, selection_end = 28}
		if reversed {
			options.selection_start, options.selection_end = options.selection_end, options.selection_start
		}
		layout := prepare_live_markdown_layout(root, options, text, 0)
		selected := ""
		for block in layout.blocks {
			for line in block.lines {
				for span in line.spans {
					testing.expect(t, utf8.valid_string(span.text))
					if span.selected do selected = fmt.tprintf("%s%s", selected, span.text)
				}
			}
		}
		testing.expect_value(t, selected, "éé wordSecond bold")
	}
}
