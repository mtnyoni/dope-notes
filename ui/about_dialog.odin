package ui

import config "../appconfig"
import theme "../theme"
import "core:fmt"
import clay "shared:clay"

AboutDialogState :: struct {
    open:               bool,
    just_opened:        bool,
    animation_progress: f32,
}

AboutDialog :: proc(dialog: ^AboutDialogState, delta_seconds: f32) {
    dialog.animation_progress = clamp(
        dialog.animation_progress +
        (dialog.open ? 1.0 : -1.0) * delta_seconds * 6,
        0,
        1,
    )
    if !dialog.open && dialog.animation_progress <= 0 {return}
    progress := dialog.animation_progress
    eased := progress * progress * (3 - 2 * progress)

    if clay.UI(clay.ID("AboutOverlay"))(
    {
        layout = clay.LayoutConfig {
            sizing = clay.Sizing {
                width = clay.SizingGrow(),
                height = clay.SizingGrow(),
            },
            childAlignment = clay.ChildAlignment{x = .Center, y = .Center},
            padding = clay.PaddingAll(20),
        },
        floating = clay.FloatingElementConfig {
            attachTo = .Root,
            attachment = clay.FloatingAttachPoints {
                element = .CenterCenter,
                parent = .CenterCenter,
            },
            zIndex = 100,
        },
        backgroundColor = clay.Color{0, 0, 0, 70 * eased},
    },
    ) {
        if clay.UI(clay.ID("AboutDialog"))(
        {
            layout = clay.LayoutConfig {
                sizing = clay.Sizing {
                    width = clay.SizingFixed(320),
                    height = clay.SizingFixed(200 * eased),
                },
                layoutDirection = .TopToBottom,
                childAlignment = clay.ChildAlignment{x = .Center},
                padding = clay.PaddingAll(24),
                childGap = 16,
            },
            clip = clay.ClipElementConfig{horizontal = true, vertical = true},
            backgroundColor = theme.Light.surface,
            cornerRadius = clay.CornerRadiusAll(12),
            border = clay.BorderElementConfig {
                width = clay.BorderWidth {
                    left = 1,
                    right = 1,
                    top = 1,
                    bottom = 1,
                },
                color = theme.Light.border,
            },
        },
        ) {
            clay.Text(
                "Dope Notes",
                clay.TextElementConfig {
                    fontSize = 22,
                    textColor = theme.Light.text,
                    wrapMode = .None,
                },
            )
            clay.Text(
                fmt.tprintf("Version %s", config.DISPLAY_VERSION),
                clay.TextElementConfig {
                    fontSize = 14,
                    textColor = theme.Light.text_secondary,
                    wrapMode = .None,
                },
            )
            clay.Text(
                "A quiet place for your notes.",
                clay.TextElementConfig {
                    fontSize = 13,
                    textColor = theme.Light.text_secondary,
                },
            )
            close_id := clay.ID("AboutClose")
            hovered := clay.PointerOver(close_id)
            if clay.UI(close_id)(
            {
                layout = clay.LayoutConfig {
                    sizing = clay.Sizing {
                        width = clay.SizingFixed(88),
                        height = clay.SizingFixed(32),
                    },
                    childAlignment = clay.ChildAlignment {
                        x = .Center,
                        y = .Center,
                    },
                },
                backgroundColor = hovered ? theme.Light.accent_hover : theme.Light.accent,
                cornerRadius = clay.CornerRadiusAll(6),
            },
            ) {
                clay.Text(
                    "Close",
                    clay.TextElementConfig {
                        fontSize = 13,
                        textColor = theme.Light.on_accent,
                    },
                )
                if hovered &&
                   clay.GetPointerState().state ==
                       .PressedThisFrame {dialog.open = false}
            }
        }
        if !dialog.just_opened &&
           dialog.open &&
           clay.GetPointerState().state == .PressedThisFrame &&
           !clay.PointerOver(clay.ID("AboutDialog")) {
            dialog.open = false
        }
    }
    dialog.just_opened = false
}
