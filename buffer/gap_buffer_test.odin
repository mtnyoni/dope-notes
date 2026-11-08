package buffer

import "core:testing"


@(test)
test_left_right_values :: proc(t: ^testing.T) {
	buf := make_gap_buffer(2)
	defer destroy_gap_buffer(&buf)

	insert(&buf, 0, '0')
	insert(&buf, 1, rune('1'))
	insert(&buf, 2, "2345678")
	insert(&buf, 0, rune('a'))

	left, right := get_strings(&buf)
	testing.expect_value(t, left, "a")
	testing.expect_value(t, right, "012345678")
}

@(test)
test_cursor_movement :: proc(t: ^testing.T) {
	buf := make_gap_buffer(20)
	defer destroy_gap_buffer(&buf)

	insert(&buf, 0, "012345678")
	shift_gap_to(&buf, 4)
	left, right := get_strings(&buf)
	testing.expect_value(t, left, "0123")
	testing.expect_value(t, right, "45678")
}
