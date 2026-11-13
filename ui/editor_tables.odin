package ui

import buffer "../buffer"
import markdown "../markdown"
import "core:strings"
import sdl "vendor:sdl3"
import commonmark "vendor:commonmark"

editor_handle_table_event :: proc(ed: ^EditorState, event: ^sdl.Event) -> bool {
	if !ed.focused || (event.type != .KEY_DOWN && event.type != .TEXT_INPUT) do return false
	layout := editor_table_layout(ed)
	cell, found := editor_table_cell_at(layout, ed.cursor)
	if !found {
		cell, found = editor_nearest_table_cell(ed, layout)
		if found do ed.cursor = clamp(ed.cursor, cell.source_start, cell.source_end)
	}
	if !found do return false
	ed.selection.start = clamp(ed.selection.start, cell.source_start, cell.source_end)
	ed.selection.end = clamp(ed.selection.end, cell.source_start, cell.source_end)
	if event.type == .TEXT_INPUT {
		editor_insert_cell_text(ed, string(event.text.text))
	} else {
		control := sdl.KMOD_CTRL & event.key.mod != {} || sdl.KMOD_GUI & event.key.mod != {}
		if control {
			switch event.key.key {
			case sdl.K_A:
				ed.selection = {start = cell.source_start, end = cell.source_end}
				ed.cursor = cell.source_end
			case sdl.K_V:
				if text := sdl.GetClipboardText(); text != nil {
					editor_insert_cell_text(ed, string(cstring(text)))
					sdl.free(text)
				}
			case sdl.K_C: return false
			case: return true
			}
		} else {
			switch event.key.key {
			case sdl.K_TAB:
				direction := sdl.KMOD_SHIFT & event.key.mod != {} ? -1 : 1
				editor_move_table_cell(ed, layout, direction, false)
			case sdl.K_RETURN, sdl.K_KP_ENTER, sdl.K_DOWN:
				editor_move_table_cell(ed, layout, 1, true)
			case sdl.K_UP:
				editor_move_table_cell(ed, layout, -1, true)
			case sdl.K_HOME:
				ed.cursor = cell.source_start
				ed.selection = {}
			case sdl.K_END:
				ed.cursor = cell.source_end
				ed.selection = {}
			case sdl.K_LEFT:
				if ed.selection.start != ed.selection.end { ed.cursor = min(ed.selection.start, ed.selection.end) } else { ed.cursor = max(cell.source_start, buffer.prev_rune_start(&ed.buf, ed.cursor)) }
				ed.selection = {}
			case sdl.K_RIGHT:
				if ed.selection.start != ed.selection.end { ed.cursor = max(ed.selection.start, ed.selection.end) } else { ed.cursor = min(cell.source_end, buffer.next_rune_end(&ed.buf, ed.cursor)) }
				ed.selection = {}
			case sdl.K_BACKSPACE:
				if !editor_delete_selection(ed) && ed.cursor > cell.source_start {
					previous := max(cell.source_start, buffer.prev_rune_start(&ed.buf, ed.cursor))
					text := editor_text(ed)
					if previous > cell.source_start && text[previous] == '|' && text[previous-1] == '\\' do previous -= 1
					buffer.remove(&ed.buf, previous, ed.cursor-previous)
					ed.cursor = previous
					ed.markdown_dirty = true
				}
			case sdl.K_DELETE:
				if !editor_delete_selection(ed) && ed.cursor < cell.source_end {
					next := min(cell.source_end, buffer.next_rune_end(&ed.buf, ed.cursor))
					text := editor_text(ed)
					if text[ed.cursor] == '\\' && next < cell.source_end && (text[next] == '|' || text[next] == '\\') do next += 1
					buffer.remove(&ed.buf, ed.cursor, next-ed.cursor)
					ed.markdown_dirty = true
				}
			case: return false
			}
		}
	}
	ed.reveal_cursor = true
	ed.has_preferred_x = false
	buffer.shift_gap_to(&ed.buf, ed.cursor)
	return true
}

editor_insert_cell_text :: proc(ed: ^EditorState, value: string) {
	editor_delete_selection(ed)
	text, _ := strings.replace_all(value, "\r\n", " ", context.temp_allocator)
	text, _ = strings.replace_all(text, "\n", " ", context.temp_allocator)
	text, _ = strings.replace_all(text, "\r", " ", context.temp_allocator)
	text, _ = strings.replace_all(text, "\\", "\\\\", context.temp_allocator)
	text, _ = strings.replace_all(text, "|", "\\|", context.temp_allocator)
	buffer.insert(&ed.buf, ed.cursor, text)
	ed.cursor += len(text)
	ed.markdown_dirty = true
}

editor_table_cell_at :: proc(layout: markdown.DocumentLayout, position: int) -> (markdown.TableCell, bool) {
	for block in layout.blocks {
		for cell in block.table_cells {
			if position >= cell.source_start && position <= cell.source_end do return cell, true
		}
	}
	return {}, false
}

editor_move_table_cell :: proc(ed: ^EditorState, layout: markdown.DocumentLayout, direction: int, vertical: bool) {
	cells := make([dynamic]markdown.TableCell, context.temp_allocator)
	current, columns := -1, 0
	for block in layout.blocks {
		for cell in block.table_cells {
			if ed.cursor >= cell.source_start && ed.cursor <= cell.source_end {
				current = len(cells)
				columns = len(block.table_cells)
			}
			append(&cells, cell)
		}
	}
	if current < 0 do return
	step := vertical ? columns*direction : direction
	target := current+step
	if target < 0 || target >= len(cells) do return
	ed.cursor = cells[target].source_start
	ed.selection = {}
}

editor_nearest_table_cell :: proc(ed: ^EditorState, layout: markdown.DocumentLayout) -> (markdown.TableCell, bool) {
	line := editor_physical_line(editor_text(ed), ed.cursor)+1
	for block, index in layout.blocks {
		if block.source_line == line {
			for cell in block.table_cells {
				if ed.cursor <= cell.source_end do return cell, true
			}
			return block.table_cells[len(block.table_cells)-1], true
		}
		// The alignment row is hidden: navigation skips to the first body cell.
		if block.table_header && line == block.source_line+1 {
			if index+1 < len(layout.blocks) && layout.blocks[index+1].source_line == line+1 do return layout.blocks[index+1].table_cells[0], true
			return block.table_cells[0], true
		}
	}
	return {}, false
}

// Keyboard editing needs source geometry, without querying the GUI context.
editor_table_layout :: proc(ed: ^EditorState) -> markdown.DocumentLayout {
	text := editor_text(ed)
	layout := markdown.DocumentLayout{blocks = make([dynamic]markdown.RenderBlock, context.temp_allocator)}
	if !strings.contains(text, "|") do return layout
	root := commonmark.parse_document_from_string(text, {})
	defer commonmark.node_free(root)
	options := editor_markdown_options(ed)
	options.load_image = nil
	base := markdown.prepare_markdown_layout(root, options)
	rows := markdown.source_lines(text)
	tables := markdown.prepare_table_rows(text, rows[:], base, options)
	for _, index in rows {
		if block, found := tables[index]; found && block.height > 0 do append(&layout.blocks, block)
	}
	return layout
}
