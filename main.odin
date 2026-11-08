package main

import "./buffer"
import "core:fmt"

main :: proc() {
	buf := buffer.make_gap_buffer(2)
	defer buffer.destroy_gap_buffer(&buf)


}
