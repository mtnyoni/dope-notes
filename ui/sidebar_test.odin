package ui

import notes "../notes"
import state "../state"
import "core:c"
import "core:testing"
import clay "shared:clay"

sidebar_test_measure :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	return {f32(text.length) * 7, 18}
}

@(test)
sidebar_description_preserves_padding :: proc(t: ^testing.T) {
	memory := make([]u8, int(clay.MinMemorySize()))
	defer delete(memory)
	clay.Initialize(
		clay.CreateArenaWithCapacityAndMemory(c.size_t(len(memory)), raw_data(memory)),
		{1080, 640},
		{},
	)
	clay.SetMeasureTextFunction(sidebar_test_measure, nil)
	app_state: state.AppState
	clay.BeginLayout()
	Sidebar(&app_state)
	commands := clay.EndLayout(1.0 / 60.0)
	panel := clay.GetElementData(clay.ID("SidebarPanel")).boundingBox
	testing.expect(t, commands.length > 0)
	for _, index in notes.notes_list {
		card := clay.GetElementData(clay.ID("ArticleCard", u32(index))).boundingBox
		description := clay.GetElementData(clay.ID("ArticleDescription", u32(index))).boundingBox
		testing.expect(t, description.x >= card.x + 8)
		testing.expect(t, description.x + description.width <= card.x + card.width - 8)
		testing.expect(t, card.x + card.width <= panel.x + panel.width - 8)
	}

	// Hovering does not select; pressing does. Holding while moving to a
	// different item must not be treated as a second click.
	first := clay.GetElementData(clay.ID("ArticleCard", 0)).boundingBox
	second := clay.GetElementData(clay.ID("ArticleCard", 1)).boundingBox
	clay.SetPointerState({first.x + 4, first.y + 4}, false)
	clay.BeginLayout()
	Sidebar(&app_state)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, app_state.current_doc, "")

	clay.SetPointerState({first.x + 4, first.y + 4}, true)
	clay.BeginLayout()
	Sidebar(&app_state)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, app_state.current_doc, notes.notes_list[0].slug)

	clay.SetPointerState({second.x + 4, second.y + 4}, true)
	clay.BeginLayout()
	Sidebar(&app_state)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, app_state.current_doc, notes.notes_list[0].slug)

	clay.SetPointerState({second.x + 4, second.y + 4}, false)
	clay.SetPointerState({second.x + 4, second.y + 4}, true)
	clay.BeginLayout()
	Sidebar(&app_state)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, app_state.current_doc, notes.notes_list[1].slug)
	editor_mouse_scrolling_test(t)

}
