package ui

import markdown "../markdown"
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
	notebooks, err := markdown.get_notes()
	testing.expect(t, err == nil)
	if err != nil do return
	defer markdown.free_notebooks(notebooks)
	app_state := state.make_app_state(notebooks)
	notebook := state.current_notebook(&app_state)
	testing.expect(t, notebook != nil && len(notebook.notes) >= 2)
	if notebook == nil || len(notebook.notes) < 2 do return
	app_state.current_doc = ""
	clay.BeginLayout()
	Sidebar(nil, &app_state)
	commands := clay.EndLayout(1.0 / 60.0)
	panel := clay.GetElementData(clay.ID("SidebarPanel")).boundingBox
	testing.expect(t, commands.length > 0)
	for _, index in notebook.notes {
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
	Sidebar(nil, &app_state)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, app_state.current_doc, "")

	clay.SetPointerState({first.x + 4, first.y + 4}, true)
	clay.BeginLayout()
	Sidebar(nil, &app_state)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, app_state.current_doc, notebook.notes[0].path)

	clay.SetPointerState({second.x + 4, second.y + 4}, true)
	clay.BeginLayout()
	Sidebar(nil, &app_state)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, app_state.current_doc, notebook.notes[0].path)

	clay.SetPointerState({second.x + 4, second.y + 4}, false)
	clay.SetPointerState({second.x + 4, second.y + 4}, true)
	clay.BeginLayout()
	Sidebar(nil, &app_state)
	commands = clay.EndLayout(1.0 / 60.0)
	testing.expect_value(t, app_state.current_doc, notebook.notes[1].path)
	editor_mouse_scrolling_test(t)
	editor_markdown_preview_test(t)

}
