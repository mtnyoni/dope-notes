package markdown

import "core:strings"
import "core:testing"
import commonmark "vendor:commonmark"

@(test)
display_equation_renders_fraction_greek_scripts_and_text :: proc(t: ^testing.T) {
	text := "$$\nP + \\frac{1}{2}\\rho v^2 + \\rho g h = \\text{constant}\n$$"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	options := RenderOptions{width = 700, measure = render_test_measure}
	layout := prepare_live_markdown_layout(root, options, text, -1)
	testing.expect_value(t, len(layout.blocks), 1)
	if len(layout.blocks) != 1 do return
	block := layout.blocks[0]
	testing.expect(t, block.math && block.height > 32)
	fraction, greek, raised, literal := false, false, false, false
	for glyph in block.formula.glyphs {
		fraction = fraction || glyph.rule
		greek = greek || glyph.text == "ρ"
		raised = raised || (glyph.text == "2" && glyph.size < 20 && glyph.y < block.formula.baseline-15)
		literal = literal || glyph.text == "constant"
		testing.expect(t, glyph.x >= 0 && glyph.y >= 0)
		testing.expect(t, glyph.x+glyph.width <= block.formula.width+0.01)
		testing.expect(t, glyph.y+glyph.height <= block.formula.height+0.01)
	}
	testing.expect(t, fraction && greek && raised && literal)
	editing := prepare_live_markdown_layout(root, options, text, 1)
	testing.expect_value(t, len(editing.blocks), 2)
	testing.expect(t, editing.blocks[0].math && editing.blocks[1].active)
}

@(test)
math_delimiters_preserve_plain_text_and_code :: proc(t: ^testing.T) {
	texts := []string{"$$\nunclosed", "```\n$$\nx^2\n$$\n```", "ordinary $5 text"}
	for text in texts {
		root := commonmark.parse_document_from_string(text, {})
		layout := prepare_live_markdown_layout(root, {width = 400}, text, -1)
		for block in layout.blocks do testing.expect(t, !block.math)
		commonmark.node_free(root)
	}
	text := "Before\n\n$$x^{2} + y_{1}$$\n\nAfter"
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	layout := prepare_live_markdown_layout(root, {width = 400}, text, -1)
	count := 0
	for block in layout.blocks { if block.math do count += 1 }
	testing.expect_value(t, count, 1)
}

@(test)
math_handles_nested_fractions_and_incomplete_input :: proc(t: ^testing.T) {
	texts := []string{"\\frac{1}{\\frac{2}{3}}", "\\frac{", "x^", "\\unknown{x}", "\\", strings.repeat("{", 100, context.temp_allocator)}
	for text in texts {
		parser := MathParser{text = text, options = {width = 400}}
		box := math_sequence(&parser, 20, false)
		testing.expect_value(t, parser.at, len(text))
		testing.expect(t, box.width >= 0 && box.height >= 0)
	}
}
