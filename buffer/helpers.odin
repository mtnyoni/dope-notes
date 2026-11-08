package buffer

text_len :: proc(buf: ^GapBuffer) -> int {
	return len(buf.buffer) - (buf.gap_end - buf.gap_start)
}

byte_at :: proc(buf: ^GapBuffer, i: int) -> u8 {
	if i < buf.gap_start do return buf.buffer[i]
	return buf.buffer[i + (buf.gap_end - buf.gap_start)]
}

prev_rune_start :: proc(buf: ^GapBuffer, cursor: BufferPosition) -> BufferPosition {
	if cursor <= 0 do return 0
	i := cursor - 1
	for i > 0 && (byte_at(buf, i) & 0xC0) == 0x80 do i -= 1
	return i
}

next_rune_end :: proc(buf: ^GapBuffer, cursor: BufferPosition) -> BufferPosition {
	n := text_len(buf)
	if cursor >= n do return n
	j := cursor + 1
	for j < n && (byte_at(buf, j) & 0xC0) == 0x80 do j += 1
	return j
}
