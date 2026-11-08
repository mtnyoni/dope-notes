package ui

import clay "shared:clay"

UILayout :: proc() {
    if clay.UI(clay.ID("Root"))({
        layout = {
            sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
            layoutDirection = .LeftToRight,
        },
    }) {
        Sidebar()
        if clay.UI(clay.ID("Content"))({
            layout = {
                sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
                layoutDirection = .LeftToRight,
            },
        }) {
            Editor()
            Annotations()
        }
    }
}
