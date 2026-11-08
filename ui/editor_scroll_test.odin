package ui

import buffer "../buffer"
import "core:testing"
import clay "shared:clay"
import sdl "vendor:sdl3"

editor_test_scroll_frame :: proc(ed: ^EditorState, input: ScrollInput = {}) {
	clay.SetPointerState(input.mouse, input.left_down)
	clay.UpdateScrollContainers(false, {}, 1.0 / 60.0)
	clay.BeginLayout()
	DocumentView(ed, input, 1.0 / 60.0)
	commands := clay.EndLayout(1.0 / 60.0)
	assert(commands.length > 0)
}

// The sidebar layout test owns the Clay context used by this integration test.
editor_mouse_scrolling_test :: proc(t: ^testing.T) {
	ed := EditorState{buf = buffer.make_gap_buffer(64), focused = true, reveal_cursor = true}
	defer buffer.destroy_gap_buffer(&ed.buf)
	for i in 0 ..< 60 do buffer.insert(&ed.buf, buffer.text_len(&ed.buf), "A line of text\n")
	buffer.shift_gap_to(&ed.buf, 0)
	for i in 0 ..< 2 do editor_test_scroll_frame(&ed)
	viewport := clay.GetElementData(clay.ID(DOCUMENT_SCROLL_ID)).boundingBox
	initial_editor := clay.GetElementData(clay.ID(EDITOR_ID)).boundingBox
	initial_annotations := clay.GetElementData(clay.ID("Annotations")).boundingBox
	initial_map := clay.GetElementData(clay.ID("AnnotationsMap")).boundingBox
	initial_indicator := clay.GetElementData(clay.ID("AnnotationMapIndicator")).boundingBox
	testing.expect(t, ed.scroll.content_height > ed.scroll.view_height)
	testing.expect(t, clay.GetElementData(clay.ID("ScrollTrack", clay.ID(DOCUMENT_SCROLL_ID).id)).found)

	editor_test_scroll_frame(&ed, {mouse = {30, 30}, wheel_y = -3, pointer_in_window = true})
	testing.expect(t, ed.scroll.offset > 0 && ed.scroll.offset < ed.scroll.target)
	testing.expect_value(t, ed.cursor, 0)
	editor_bounds := clay.GetElementData(clay.ID(EDITOR_ID)).boundingBox
	annotation_bounds := clay.GetElementData(clay.ID("Annotations")).boundingBox
	testing.expect(t, abs(initial_editor.y - editor_bounds.y - ed.scroll.offset) < 0.1)
	testing.expect(t, abs(initial_annotations.y - annotation_bounds.y - ed.scroll.offset) < 0.1)
	map_bounds := clay.GetElementData(clay.ID("AnnotationsMap")).boundingBox
	indicator := clay.GetElementData(clay.ID("AnnotationMapIndicator")).boundingBox
	testing.expect_value(t, map_bounds.y, initial_map.y)
	testing.expect(t, indicator.y > initial_indicator.y)
	testing.expect(t, indicator.x >= map_bounds.x && indicator.x + indicator.width <= map_bounds.x + map_bounds.width)

	// Wheel input over the annotation pane controls the same parent.
	previous_target := ed.scroll.target
	editor_test_scroll_frame(&ed, {mouse = {initial_annotations.x + 20, 30}, wheel_y = -0.25, pointer_in_window = true})
	testing.expect_value(t, ed.scroll.target, previous_target + 0.25 * SCROLL_WHEEL_DISTANCE)
	previous_target = ed.scroll.target
	editor_test_scroll_frame(&ed, {mouse = {-10, -10}, wheel_y = -3, pointer_in_window = true})
	testing.expect_value(t, ed.scroll.target, previous_target)
	for i in 0 ..< 120 do editor_test_scroll_frame(&ed)
	testing.expect_value(t, ed.scroll.offset, ed.scroll.target)
	testing.expect(t, ed.scroll.offset > 0) // no idle snap to the caret

	e := sdl.Event{}
	e.type = .KEY_DOWN
	e.key.key = sdl.K_LEFT
	editor_handle_event(&ed, &e)
	editor_test_scroll_frame(&ed)
	testing.expect_value(t, ed.scroll.target, f32(0))
	for i in 0 ..< 120 do editor_test_scroll_frame(&ed)
	testing.expect_value(t, ed.scroll.offset, f32(0))

	editor_test_scroll_frame(&ed, {mouse = {30, 30}, wheel_y = -10000, pointer_in_window = true})
	for i in 0 ..< 120 do editor_test_scroll_frame(&ed)
	testing.expect_value(t, ed.scroll.offset, ed.scroll.content_height - ed.scroll.view_height)
	thumb := clay.GetElementData(clay.ID("ScrollThumb", clay.ID(DOCUMENT_SCROLL_ID).id)).boundingBox
	testing.expect(t, abs(thumb.y + thumb.height - (viewport.y + viewport.height)) < 1)
	map_bounds = clay.GetElementData(clay.ID("AnnotationsMap")).boundingBox
	indicator = clay.GetElementData(clay.ID("AnnotationMapIndicator")).boundingBox
	testing.expect_value(t, map_bounds.y, viewport.y)
	testing.expect(t, indicator.y + indicator.height <= map_bounds.y + map_bounds.height - EDITOR_PADDING + 1)

	// Dragging follows the pointer directly, including outside the viewport.
	editor_test_scroll_frame(&ed, {mouse = {thumb.x + 2, thumb.y + thumb.height / 2}, left_down = true, left_pressed = true, pointer_in_window = true})
	testing.expect(t, ed.scroll.dragging)
	editor_test_scroll_frame(&ed, {mouse = {thumb.x + 2, viewport.y - 100}, left_down = true, pointer_in_window = true})
	testing.expect_value(t, ed.scroll.offset, f32(0))
	editor_test_scroll_frame(&ed)
	testing.expect(t, !ed.scroll.dragging)

	// Clicking the track pages down with easing.
	editor_test_scroll_frame(&ed, {mouse = {thumb.x + 2, viewport.y + viewport.height - 5}, left_pressed = true, left_down = true, pointer_in_window = true})
	testing.expect(t, ed.scroll.target > 0 && ed.scroll.offset < ed.scroll.target)
	for i in 0 ..< 120 do editor_test_scroll_frame(&ed)
	saved_scroll := ed.scroll.offset

	short := EditorState{buf = buffer.make_gap_buffer(64), reveal_cursor = true}
	defer buffer.destroy_gap_buffer(&short.buf)
	buffer.insert(&short.buf, 0, "Short note")
	for i in 0 ..< 2 do editor_test_scroll_frame(&short)
	testing.expect_value(t, short.scroll.offset, f32(0))
	testing.expect(t, !clay.GetElementData(clay.ID("ScrollTrack", clay.ID(DOCUMENT_SCROLL_ID).id)).found)
	editor_test_scroll_frame(&ed)
	testing.expect_value(t, ed.scroll.offset, saved_scroll)
}

@(test)
scroll_easing_is_independent_of_frame_rate :: proc(t: ^testing.T) {
	viewport := clay.BoundingBox{0, 0, 200, 200}
	a := ScrollState{content_height = 1200, view_height = 200, target = 500}
	b := a
	for i in 0 ..< 30 do scroll_update(&a, {}, viewport, 1.0 / 30.0)
	for i in 0 ..< 120 do scroll_update(&b, {}, viewport, 1.0 / 120.0)
	testing.expect(t, abs(a.offset - b.offset) < 0.1)
	testing.expect_value(t, a.offset, f32(500))
}
