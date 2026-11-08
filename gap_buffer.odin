package main

import "base:runtime"
import "core:bufio"
import "core:debug/trace"
import "core:mem"
import "core:unicode/utf8"

BufferPosition :: int
GapBuffer :: struct {
	buffer:    []u8,
	gap_start: BufferPosition,
	gap_end:   BufferPosition,
	allocator: runtime.Allocator,
}

make_gap_buffer :: proc(n_bytes: int, allocator := context.allocator) -> GapBuffer {
	b := GapBuffer {
		buffer    = make([]u8, n_bytes, allocator),
		gap_end   = n_bytes,
		allocator = allocator,
	}

	return b
}

destroy_gap_buffer :: proc(buf: ^GapBuffer) {
	delete(buf.buffer)
}

shift_gap_to :: proc(buf: ^GapBuffer, cursor: BufferPosition) {
	gap_len := buf.gap_end - buf.gap_start
	target_cursor := min(cursor, len(buf.buffer) - gap_len)
	if target_cursor == buf.gap_start do return

	if buf.gap_start < target_cursor {
		delta := target_cursor - buf.gap_start
		mem.copy(&buf.buffer[buf.gap_start], &buf.buffer[buf.gap_end], delta)
		buf.gap_start += delta
		buf.gap_end += delta
	} else if buf.gap_start > target_cursor {
		delta := buf.gap_start - target_cursor
		mem.copy(&buf.buffer[buf.gap_end - delta], &buf.buffer[buf.gap_start - delta], delta)
		buf.gap_start -= delta
		buf.gap_end -= delta
	}
}

check_gap_size :: proc(buf: ^GapBuffer, n_required: int) {
	gap_len := buf.gap_end - buf.gap_start
	if gap_len >= n_required do return


	new_cap := max(len(buf.buffer) * 2, len(buf.buffer) + n_required)
	new_buf := make([]u8, new_cap, buf.allocator)

	left_len := buf.gap_start
	right_len := len(buf.buffer) - buf.gap_end
	new_gap_end := new_cap - right_len

	if left_len > 0 {
		copy(new_buf[:left_len], buf.buffer[:left_len])
	}

	if right_len > 0 {
		copy(new_buf[new_gap_end:], buf.buffer[buf.gap_end:])
	}

	delete(buf.buffer)
	buf.buffer = new_buf
	buf.gap_end = new_gap_end
}

insert :: proc {
	insert_char,
	insert_rune,
	insert_slice,
	insert_string,
}

insert_char :: proc(buf: ^GapBuffer, cursor: BufferPosition, char: u8) {
	check_gap_size(buf, 1)
	shift_gap_to(buf, cursor)

	buf.buffer[buf.gap_start] = char
	buf.gap_start += 1
}

insert_rune :: proc(buf: ^GapBuffer, cursor: BufferPosition, r: rune) {
	bytes, length := utf8.encode_rune(r)
	insert_slice(buf, cursor, bytes[:length])
}

insert_slice :: proc(buf: ^GapBuffer, cursor: BufferPosition, slice: []u8) {
	check_gap_size(buf, len(slice))
	shift_gap_to(buf, cursor)

	copy_slice(buf.buffer[buf.gap_start:], slice)
	buf.gap_start += len(slice)
}

insert_string :: proc(buf: ^GapBuffer, cursor: BufferPosition, str: string) {
	insert_slice(buf, cursor, transmute([]u8)str)
}

remove :: proc(buf: ^GapBuffer, cursor: BufferPosition, count: int) {
	shift_gap_to(buf, cursor)
	buf.gap_end = min(buf.gap_end + count, len(buf.buffer))
}

get_strings :: proc(buf: ^GapBuffer) -> (left: string, right: string) {
	left = string(buf.buffer[:buf.gap_start])
	right = string(buf.buffer[buf.gap_end:])
	return
}
