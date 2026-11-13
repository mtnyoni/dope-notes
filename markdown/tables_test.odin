package markdown

import "core:testing"
import commonmark "vendor:commonmark"

@(test)
table_renders_headers_bold_cells_and_alignment :: proc(t: ^testing.T) {
	text := "| Project | Status | Lead | Due Date |\n| :--- | :--- | :---: | ---: |\n| **Apex9** | In Progress | Tawanda | Q4 2026 |\n| **Rent-Easy** | Active | Tawanda | Ongoing |\n| **HRMS** | Review | Tinaye | Q3 2026 |"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	layout := prepare_live_markdown_layout(root, {width = 600, measure = render_test_measure}, text, -1)
	testing.expect_value(t, len(layout.blocks), 4)
	if len(layout.blocks) != 4 do return
	for block in layout.blocks {
		testing.expect(t, block.table)
		testing.expect_value(t, len(block.table_cells), 4)
		testing.expect_value(t, block.table_cells[0].width, f32(150))
		testing.expect(t, block.table_cells[0].alignment == .Left)
		testing.expect(t, block.table_cells[2].alignment == .Center)
		testing.expect(t, block.table_cells[3].alignment == .Right)
	}
	testing.expect(t, layout.blocks[0].table_header)
	testing.expect(t, layout.blocks[0].table_cells[0].lines[0].spans[0].style & 1 != 0)
	span := layout.blocks[1].table_cells[0].lines[0].spans[0]
	testing.expect_value(t, span.text, "Apex9")
	testing.expect(t, span.style & 1 != 0)
	// Editing a table row keeps the entire grid formatted.
	editing := prepare_live_markdown_layout(root, {width = 600}, text, 2)
	testing.expect_value(t, len(editing.blocks), 4)
	testing.expect(t, editing.blocks[1].active && editing.blocks[1].table)
	testing.expect(t, editing.blocks[0].table && editing.blocks[2].table)
}

@(test)
table_parser_rejects_code_and_invalid_separators :: proc(t: ^testing.T) {
	texts := []string{"```\n| A | B |\n| --- | --- |\n| x | y |\n```", "| A | B |\n| no | --- |\n| x | y |"}
	for text in texts {
		root := commonmark.parse_document_from_string(text, {})
		layout := prepare_live_markdown_layout(root, {width = 200}, text, -1)
		for block in layout.blocks do testing.expect(t, !block.table)
		commonmark.node_free(root)
	}
}

@(test)
table_handles_empty_cells_escaped_pipes_and_wrapping :: proc(t: ^testing.T) {
	text := "| A | B |\n| --- | --- |\n| one\\|two | |\n| a very long cell to wrap | short |"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	layout := prepare_live_markdown_layout(root, {width = 160, measure = render_test_measure}, text, -1)
	testing.expect_value(t, len(layout.blocks), 3)
	if len(layout.blocks) != 3 do return
	testing.expect_value(t, len(layout.blocks[1].table_cells), 2)
	testing.expect_value(t, len(layout.blocks[1].table_cells[1].lines[0].spans), 1)
	testing.expect(t, len(layout.blocks[2].table_cells[0].lines) > 1)
	testing.expect(t, layout.blocks[2].height > 40)
}
