package main

import "core:fmt"


main :: proc() {
	buf := make_gap_buffer(2)
	insert(&buf, 0, '0')
	insert(&buf, 1, rune('1'))

	insert(&buf, 4, "tawanda")
	left, right := get_strings(&buf)
	fmt.printf("left: %s | right: %s\n", left, right)
}
