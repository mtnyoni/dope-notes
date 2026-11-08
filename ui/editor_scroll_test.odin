package ui

import buffer "../buffer"
import "core:testing"
import clay "shared:clay"
import sdl "vendor:sdl3"

// Called by the sidebar layout test, which owns the shared Clay context.
editor_mouse_scrolling_test :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(64), focused = true, restore_scroll = true, reveal_cursor = true}
	defer buffer.destroy_gap_buffer(&ed.buf)
	for i in 0 ..< 60 do buffer.insert(&ed.buf, buffer.text_len(&ed.buf), "A line of text\n")
	buffer.shift_gap_to(&ed.buf, 0)
	for i in 0 ..< 2 {
		clay.BeginLayout()
		Editor(&ed)
		commands := clay.EndLayout(1.0 / 60.0)
		testing.expect(t, commands.length > 0)
	}
	viewport := clay.GetElementData(clay.ID(EDITOR_SCROLL_ID)).boundingBox
	data := clay.GetScrollContainerData(clay.ID(EDITOR_SCROLL_ID))
	testing.expect(t, data.found && data.contentDimensions.height > data.scrollContainerDimensions.height)
	testing.expect(t, clay.GetElementData(clay.ID("ScrollTrack", clay.ID(EDITOR_SCROLL_ID).id)).found)

	clay.SetPointerState({viewport.x + 30, viewport.y + 30}, false)
	clay.UpdateScrollContainers(false, {0, -3}, 1.0 / 60.0)
	clay.BeginLayout()
	Editor(&ed)
	commands := clay.EndLayout(1.0 / 60.0)
	testing.expect(t, ed.scroll_y > 0)
	scrolled := ed.scroll_y
	testing.expect_value(t, ed.cursor, 0)
	thumb := clay.GetElementData(clay.ID("ScrollThumb", clay.ID(EDITOR_SCROLL_ID).id)).boundingBox
	testing.expect(t, thumb.y > viewport.y)
	testing.expect(t, thumb.y + thumb.height <= viewport.y + viewport.height)

	// An idle frame preserves manual scrolling, even with the caret at the top.
	clay.UpdateScrollContainers(false, {}, 1.0 / 60.0)
	clay.BeginLayout()
	Editor(&ed)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, ed.scroll_y, scrolled)

	// Keyboard interaction reveals the caret again.
	e := sdl.Event{}
	e.type = .KEY_DOWN
	e.key.key = sdl.K_LEFT
	editor_handle_event(&ed, &e)
	clay.BeginLayout()
	Editor(&ed)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, ed.scroll_y, f32(0))

	// Excess wheel input is clamped; the thumb cannot leave the track.
	clay.SetPointerState({viewport.x + 30, viewport.y + 30}, false)
	clay.UpdateScrollContainers(false, {0, -10000}, 1.0 / 60.0)
	clay.BeginLayout()
	Editor(&ed)
	commands = clay.EndLayout(1.0 / 60.0)
	data = clay.GetScrollContainerData(clay.ID(EDITOR_SCROLL_ID))
	testing.expect_value(t, ed.scroll_y, data.contentDimensions.height - data.scrollContainerDimensions.height)
	thumb = clay.GetElementData(clay.ID("ScrollThumb", clay.ID(EDITOR_SCROLL_ID).id)).boundingBox
	testing.expect(t, abs(thumb.y + thumb.height - (viewport.y + viewport.height)) < 1)
	// Different notes share Clay's viewport ID, but keep independent offsets.
	saved_scroll := ed.scroll_y
	short := EditorState{buf = buffer.make_gap_buffer(64), restore_scroll = true, reveal_cursor = true}
	defer buffer.destroy_gap_buffer(&short.buf)
	buffer.insert(&short.buf, 0, "Short note")
	for i in 0 ..< 2 {
		clay.BeginLayout()
		Editor(&short)
		commands = clay.EndLayout(1.0 / 60.0)
	}
	testing.expect_value(t, short.scroll_y, f32(0))
	testing.expect(t, !clay.GetElementData(clay.ID("ScrollTrack", clay.ID(EDITOR_SCROLL_ID).id)).found)
	ed.restore_scroll = true
	clay.BeginLayout()
	Editor(&ed)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, ed.scroll_y, saved_scroll)

}
