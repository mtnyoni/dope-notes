package ui

import buffer "../buffer"
import markdown "../markdown"
import "core:strings"
import commonmark "vendor:commonmark"
import sdl "vendor:sdl3"

editor_handle_formula_event :: proc(ed: ^EditorState, event: ^sdl.Event) -> bool {
	if !ed.focused || (event.type != .TEXT_INPUT && event.type != .KEY_DOWN) do return false
	block, found := editor_current_formula(ed)
	if !found do return false
	ed.cursor = clamp(ed.cursor, block.formula_source_start, block.formula_source_end)
	ed.selection.start = clamp(ed.selection.start, block.formula_source_start, block.formula_source_end)
	ed.selection.end = clamp(ed.selection.end, block.formula_source_start, block.formula_source_end)
	if event.type == .TEXT_INPUT {
		editor_insert_formula_text(ed, block, string(event.text.text))
	} else {
		control := sdl.KMOD_CTRL & event.key.mod != {} || sdl.KMOD_GUI & event.key.mod != {}
		if control {
			switch event.key.key {
			case sdl.K_A:
				ed.selection = {start = block.formula_source_start, end = block.formula_source_end}
				ed.cursor = block.formula_source_end
			case sdl.K_C: return false
			case sdl.K_V:
				if text := sdl.GetClipboardText(); text != nil {
					editor_insert_formula_text(ed, block, string(cstring(text)))
					sdl.free(text)
				}
			case: return true
			}
		} else {
			switch event.key.key {
			case sdl.K_LEFT, sdl.K_RIGHT:
				left := event.key.key == sdl.K_LEFT
				if ed.selection.start != ed.selection.end {
					ed.cursor = left ? min(ed.selection.start, ed.selection.end) : max(ed.selection.start, ed.selection.end)
				} else {
					ed.cursor = editor_formula_boundary(block, ed.cursor, left)
				}
				ed.selection = {}
			case sdl.K_HOME:
				ed.cursor = block.formula_source_start
				ed.selection = {}
			case sdl.K_END:
				ed.cursor = block.formula_source_end
				ed.selection = {}
			case sdl.K_UP, sdl.K_DOWN:
				x, y, height := markdown.math_caret(block, ed.cursor)
				direction: f32 = event.key.key == sdl.K_UP ? -1 : 1
				ed.cursor = markdown.math_pick_cursor(block, x+max(0,(ed.content_width-block.formula.width)/2), y+(block.height-block.formula.height)/2+direction*(height+8), ed.content_width)
				ed.selection = {}
			case sdl.K_BACKSPACE, sdl.K_DELETE:
				if !editor_delete_formula_selection(ed, block) {
					left := event.key.key == sdl.K_BACKSPACE
					chosen := -1
					for glyph, index in block.formula.glyphs {
						if glyph.rule || glyph.source_start == glyph.source_end do continue
						if left && glyph.source_end <= ed.cursor {
							if chosen < 0 || glyph.source_end > block.formula.glyphs[chosen].source_end do chosen = index
						}
						if !left && glyph.source_start >= ed.cursor {
							if chosen < 0 || glyph.source_start < block.formula.glyphs[chosen].source_start do chosen = index
						}
					}
					if chosen >= 0 {
						glyph := block.formula.glyphs[chosen]
						buffer.remove(&ed.buf, glyph.source_start, glyph.source_end-glyph.source_start)
						ed.cursor = glyph.source_start
						ed.markdown_dirty = true
					}
				}
			case sdl.K_RETURN, sdl.K_KP_ENTER:
				rows := markdown.source_lines(editor_text(ed))
				end := rows[block.source_end_line-1].end
				buffer.insert(&ed.buf, end, "\n\n")
				ed.cursor = end+2
				ed.selection = {}
				ed.markdown_dirty = true
			case: return false
			}
		}
	}
	ed.reveal_cursor = true
	ed.has_preferred_x = false
	buffer.shift_gap_to(&ed.buf, ed.cursor)
	return true
}

editor_insert_formula_text :: proc(ed: ^EditorState, block: markdown.RenderBlock, text: string) {
	editor_delete_formula_selection(ed, block)
	value, _ := strings.replace_all(text, "\n", " ", context.temp_allocator)
	value, _ = strings.replace_all(value, "\r", " ", context.temp_allocator)
	buffer.insert(&ed.buf, ed.cursor, value)
	ed.cursor += len(value)
	ed.markdown_dirty = true
}

editor_delete_formula_selection :: proc(ed: ^EditorState, block: markdown.RenderBlock) -> bool {
	start := clamp(min(ed.selection.start, ed.selection.end), block.formula_source_start, block.formula_source_end)
	end := clamp(max(ed.selection.start, ed.selection.end), block.formula_source_start, block.formula_source_end)
	ed.selection = {}
	if start == end do return false
	if start == block.formula_source_start && end == block.formula_source_end {
		buffer.remove(&ed.buf, start, end-start)
		ed.cursor = start
		ed.markdown_dirty = true
		return true
	}
	removed := false
	previous := end
	for index := len(block.formula.glyphs)-1; index >= 0; index -= 1 {
		glyph := block.formula.glyphs[index]
		if glyph.rule || glyph.source_start < start || glyph.source_end > previous || glyph.source_start == glyph.source_end do continue
		buffer.remove(&ed.buf, glyph.source_start, glyph.source_end-glyph.source_start)
		ed.cursor = glyph.source_start
		previous = glyph.source_start
		removed = true
	}
	if removed do ed.markdown_dirty = true
	return removed
}

editor_formula_boundary :: proc(block: markdown.RenderBlock, position: int, left: bool) -> int {
	best := left ? block.formula_source_start : block.formula_source_end
	for glyph in block.formula.glyphs {
		if glyph.rule do continue
		for candidate in ([2]int{glyph.source_start, glyph.source_end}) {
			if left && candidate < position do best = max(best, candidate)
			if !left && candidate > position do best = min(best, candidate)
		}
	}
	return best
}

editor_current_formula :: proc(ed: ^EditorState) -> (markdown.RenderBlock, bool) {
	text := editor_text(ed)
	if !strings.contains(text, "$$") do return {}, false
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	options := editor_markdown_options(ed)
	options.load_image = nil
	rows := markdown.source_lines(text)
	base := markdown.prepare_markdown_layout(root, options)
	formulae := markdown.prepare_math_rows(text, rows[:], base, options)
	line := editor_physical_line(text, ed.cursor)+1
	for _, index in rows {
		if block, ok := formulae[index]; ok && block.height > 0 && line >= block.source_line && line <= block.source_end_line do return block, true
	}
	return {}, false
}
