package markdown

import "core:strings"
import theme "../theme"
import clay "shared:clay"

MathGlyph :: struct {
	text: string,
	source_start, source_end: int,
	mapped: bool,
	x, y, width, height: f32,
	size: u16,
	style: u16,
	rule: bool,
}
MathBox :: struct {
	glyphs: [dynamic]MathGlyph,
	width, height, baseline: f32,
}
MathParser :: struct {
	text: string,
	at, depth: int,
	options: RenderOptions,
}

render_math :: proc(block: RenderBlock, options: RenderOptions) {
	box := block.formula
	if clay.UI()({layout = {
		sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
		childAlignment = {x = .Center, y = .Center},
	}, clip = {horizontal = true}}) {
		if clay.UI()({layout = {sizing = {width = clay.SizingFixed(box.width), height = clay.SizingFixed(box.height)}}}) {
			for glyph in box.glyphs {
				if clay.UI()({
					layout = {sizing = {width = clay.SizingFixed(glyph.width), height = clay.SizingFixed(glyph.height)}},
					floating = {attachTo = .Parent, offset = {glyph.x, glyph.y}, pointerCaptureMode = .Passthrough},
					backgroundColor = glyph.rule ? theme.Light.text : ((glyph.source_end > min(options.selection_start, options.selection_end) && glyph.source_start < max(options.selection_start, options.selection_end)) ? theme.Light.selection : clay.Color{}),
				}) {
					if !glyph.rule do clay.Text(glyph.text, {fontSize = glyph.size, fontId = glyph.style, textColor = theme.Light.text, wrapMode = .None})
				}
			}
			if options.show_caret && options.cursor >= block.formula_source_start && options.cursor <= block.formula_source_end {
				x, y, height := math_caret(block, options.cursor)
				if clay.UI(clay.ID("Caret"))({
					layout = {sizing = {width = clay.SizingFixed(2), height = clay.SizingFixed(height)}},
					floating = {attachTo = .Parent, offset = {x, y}, zIndex = 1, pointerCaptureMode = .Passthrough},
					backgroundColor = theme.Light.text,
				}) {}
			}
		}
	}
}

prepare_math_rows :: proc(source: string, rows: []SourceLine, base: DocumentLayout, options: RenderOptions) -> map[int]RenderBlock {
	result := make(map[int]RenderBlock, context.temp_allocator)
	for index := 0; index < len(rows); index += 1 {
		line := strings.trim_space(source[rows[index].start:rows[index].end])
		if !strings.has_prefix(line, "$$") do continue
		in_code := false
		for block in base.blocks {
			if block.code && index+1 >= block.source_line && index+1 <= block.source_end_line do in_code = true
		}
		if in_code do continue
		end := index
		formula := ""
		start_offset := rows[index].start+strings.index(source[rows[index].start:rows[index].end], line)+2
		if len(line) >= 4 && strings.has_suffix(line, "$$") {
			formula = line[2:len(line)-2]
		} else if line == "$$" {
			end = index+1
			for end < len(rows) && strings.trim_space(source[rows[end].start:rows[end].end]) != "$$" do end += 1
			if end >= len(rows) do continue
			start_offset = rows[index].end+1
			formula = source[start_offset:rows[end].start]
		} else { continue }
		untrimmed_start := start_offset
		for len(formula) > 0 && (formula[0] == '\n' || formula[0] == '\r' || formula[0] == ' ') { formula = formula[1:]; start_offset += 1 }
		formula = strings.trim_right(formula, "\r\n ")
		if len(formula) == 0 do start_offset = untrimmed_start
		parser := MathParser{text = formula, options = options}
		box := math_sequence(&parser, 20, false)
		if len(box.glyphs) == 0 do box = math_text("", 20, options, 0)
		for &glyph in box.glyphs {
			glyph.source_start += start_offset
			glyph.source_end += start_offset
		}
		for row in index..=end {
			block := RenderBlock{math = true, source_line = row+1, source_end_line = end+1}
			if row == index {
				block.formula = box
				block.formula_source_start = start_offset
				block.formula_source_end = start_offset+len(formula)
				block.height = max(32, box.height)+16
			}
			result[row] = block
		}
		index = end
	}
	return result
}

math_sequence :: proc(parser: ^MathParser, size: u16, grouped: bool) -> MathBox {
	box := MathBox{glyphs = make([dynamic]MathGlyph, context.temp_allocator)}
	for parser.at < len(parser.text) {
		if parser.text[parser.at] == '}' {
			parser.at += 1
			if grouped do break
			continue
		}
		atom := math_atom(parser, size)
		for parser.at < len(parser.text) && (parser.text[parser.at] == '^' || parser.text[parser.at] == '_') {
			super := parser.text[parser.at] == '^'
			parser.at += 1
			script := math_argument(parser, max(8, u16(f32(size)*0.65)))
			y := super ? -script.height*0.45 : atom.baseline*0.7
			if y < 0 {
				for &glyph in atom.glyphs do glyph.y -= y
				atom.baseline -= y
				atom.height -= y
				y = 0
			}
			math_place(&atom, script, atom.width, y)
			atom.width += script.width
			atom.height = max(atom.height, y+script.height)
		}
		y := box.baseline-atom.baseline
		if y < 0 {
			for &glyph in box.glyphs do glyph.y -= y
			box.height -= y
			box.baseline = atom.baseline
			y = 0
		}
		math_place(&box, atom, box.width, y)
		box.width += atom.width
		box.height = max(box.height, y+atom.height)
	}
	return box
}

math_atom :: proc(parser: ^MathParser, size: u16) -> MathBox {
	start := parser.at
	box := math_parse_atom(parser, size)
	if len(box.glyphs) == 0 {
		position := parser.at
		if position > start && parser.text[position-1] == '}' do position -= 1
		box = math_text("", size, parser.options, position)
	}
	for &glyph in box.glyphs {
		if !glyph.rule && !glyph.mapped {
			glyph.source_start, glyph.source_end = start, parser.at
			glyph.mapped = true
		}
	}
	return box
}

math_parse_atom :: proc(parser: ^MathParser, size: u16) -> MathBox {
	if parser.at >= len(parser.text) do return math_text("", size, parser.options)
	start := parser.at
	parser.at += 1
	byte := parser.text[start]
	if byte == '{' && parser.depth < 32 {
		parser.depth += 1
		box := math_sequence(parser, size, true)
		parser.depth -= 1
		return box
	}
	if byte == '\\' {
		for parser.at < len(parser.text) && ((parser.text[parser.at] >= 'a' && parser.text[parser.at] <= 'z') || (parser.text[parser.at] >= 'A' && parser.text[parser.at] <= 'Z')) do parser.at += 1
		command := parser.text[start+1:parser.at]
		if command == "frac" && parser.depth < 32 {
			parser.depth += 1
			numerator := math_argument(parser, max(8, u16(f32(size)*0.85)))
			denominator := math_argument(parser, max(8, u16(f32(size)*0.85)))
			parser.depth -= 1
			box := MathBox{glyphs = make([dynamic]MathGlyph, context.temp_allocator)}
			box.width = max(numerator.width, denominator.width)+8
			box.height = numerator.height+denominator.height+8
			box.baseline = numerator.height+4+f32(size)*0.25
			math_place(&box, numerator, (box.width-numerator.width)/2, 0)
			math_place(&box, denominator, (box.width-denominator.width)/2, numerator.height+8)
			append(&box.glyphs, MathGlyph{width = box.width, height = 1, y = numerator.height+4, rule = true})
			return box
		}
		if command == "text" || command == "mathrm" {
			math_skip_space(parser)
			if parser.at < len(parser.text) && parser.text[parser.at] == '{' {
				parser.at += 1
				begin := parser.at
				depth := 1
				for parser.at < len(parser.text) {
					b := parser.text[parser.at]
					if b == '{' do depth += 1
					if b == '}' do depth -= 1
					if depth == 0 do break
					parser.at += 1
				}
				text := parser.text[begin:parser.at]
				if parser.at < len(parser.text) do parser.at += 1
				return math_text(text, size, parser.options, begin)
			}
		}
		symbol := command
		switch command {
		case "rho": symbol = "ρ"
		case "alpha": symbol = "α"
		case "beta": symbol = "β"
		case "gamma": symbol = "γ"
		case "delta": symbol = "δ"
		case "Delta": symbol = "Δ"
		case "theta": symbol = "θ"
		case "lambda": symbol = "λ"
		case "mu": symbol = "μ"
		case "sigma": symbol = "σ"
		case "pi": symbol = "π"
		case "omega": symbol = "ω"
		case "times": symbol = "×"
		case "cdot": symbol = "·"
		case "pm": symbol = "±"
		case "infty": symbol = "∞"
		case "leq": symbol = "≤"
		case "geq": symbol = "≥"
		case "neq": symbol = "≠"
		case: return math_text(parser.text[start:parser.at], size, parser.options)
		}
		return math_text(symbol, size, parser.options)
	}
	for parser.at < len(parser.text) && (parser.text[parser.at] & 0xC0) == 0x80 do parser.at += 1
	text := parser.text[start:parser.at]
	if byte == '\n' || byte == '\r' || byte == '\t' do text = " "
	return math_text(text, size, parser.options)
}

math_argument :: proc(parser: ^MathParser, size: u16) -> MathBox {
	math_skip_space(parser)
	return math_atom(parser, size)
}

math_skip_space :: proc(parser: ^MathParser) {
	for parser.at < len(parser.text) && (parser.text[parser.at] == ' ' || parser.text[parser.at] == '\n' || parser.text[parser.at] == '\r') do parser.at += 1
}

math_text :: proc(text: string, size: u16, options: RenderOptions, source_start := -1) -> MathBox {
	height := f32(size)*1.3
	box := MathBox{height = height, baseline = f32(size), glyphs = make([dynamic]MathGlyph, context.temp_allocator)}
	at := 0
	for at < len(text) || (at == 0 && len(text) == 0) {
		next := min(at+1, len(text))
		for next < len(text) && (text[next]&0xC0) == 0x80 do next += 1
		part := text[at:next]
		width := span_width(TextSpan{text = part}, size, options)
		append(&box.glyphs, MathGlyph{text = part, x = box.width, width = width, height = height, size = size, mapped = source_start >= 0, source_start = max(0, source_start)+at, source_end = max(0, source_start)+next})
		box.width += width
		if next == at do break
		at = next
	}
	return box
}

math_place :: proc(target: ^MathBox, child: MathBox, x, y: f32) {
	for glyph in child.glyphs {
		copy := glyph
		copy.x += x
		copy.y += y
		append(&target.glyphs, copy)
	}
}

math_caret :: proc(block: RenderBlock, position: int) -> (x, y, height: f32) {
	height = 20
	best := 0x7fffffff
	for glyph in block.formula.glyphs {
		if glyph.rule do continue
		for side in 0..<2 {
			offset := side == 0 ? glyph.source_start : glyph.source_end
			distance := abs(position-offset)
			if distance < best {
				best = distance
				x = glyph.x+(side == 0 ? 0 : glyph.width)
				y = glyph.y
				height = f32(glyph.size)
			}
		}
	}
	return
}

math_pick_cursor :: proc(block: RenderBlock, x, y, width: f32) -> int {
	local_x := x-max(0, (width-block.formula.width)/2)
	local_y := y-(block.height-block.formula.height)/2
	best: f32 = 1e30
	position := block.formula_source_start
	for glyph in block.formula.glyphs {
		if glyph.rule do continue
		for side in 0..<2 {
			x := glyph.x+(side == 0 ? 0 : glyph.width)
			y := clamp(local_y, glyph.y, glyph.y+glyph.height)
			distance := (local_x-x)*(local_x-x)+(local_y-y)*(local_y-y)
			if distance < best {
				best = distance
				position = side == 0 ? glyph.source_start : glyph.source_end
			}
		}
	}
	return clamp(position, block.formula_source_start, block.formula_source_end)
}
