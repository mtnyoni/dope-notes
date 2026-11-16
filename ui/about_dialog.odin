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

AboutDialog :: proc(
    dialog: ^AboutDialogState,
    delta_seconds: f32,
    maximized: bool,
) {
    dialog.animation_progress = clamp(
        dialog.animation_progress +
        (dialog.open ? 1.0 : -1.0) * delta_seconds * 6,
        0,
        1,
    )
    if !dialog.open && dialog.animation_progress <= 0 {return}
    progress := dialog.animation_progress
    eased := progress * progress * (3 - 2 * progress)
    scale := 0.9 + 0.1 * eased

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
        cornerRadius = clay.CornerRadiusAll(maximized ? 0 : 12),
    },
    ) {
        if clay.UI(clay.ID("AboutDialog"))(
        {
            layout = clay.LayoutConfig {
                sizing = clay.Sizing {
                    width = clay.SizingFixed(320 * scale),
                    height = clay.SizingFixed(200 * scale),
                },
                layoutDirection = .TopToBottom,
                childAlignment = clay.ChildAlignment{x = .Center},
                padding = clay.PaddingAll(u16(24 * scale)),
                childGap = u16(16 * scale),
            },
            clip = clay.ClipElementConfig{horizontal = true, vertical = true},
            backgroundColor = dialog_color_opacity(theme.Light.surface, eased),
            cornerRadius = clay.CornerRadiusAll(12 * scale),
            border = clay.BorderElementConfig {
                width = clay.BorderWidth {
                    left = 1,
                    right = 1,
                    top = 1,
                    bottom = 1,
                },
                color = dialog_color_opacity(theme.Light.border, eased),
            },
        },
        ) {
            clay.Text(
                "Dope Notes",
                clay.TextElementConfig {
                    fontSize = u16(22 * scale),
                    textColor = dialog_color_opacity(theme.Light.text, eased),
                    wrapMode = .None,
                },
            )
            clay.Text(
                fmt.tprintf("Version %s", config.DISPLAY_VERSION),
                clay.TextElementConfig {
                    fontSize = u16(14 * scale),
                    textColor = dialog_color_opacity(
                        theme.Light.text_secondary,
                        eased,
                    ),
                    wrapMode = .None,
                },
            )
            clay.Text(
                "A quiet place for your notes.",
                clay.TextElementConfig {
                    fontSize = u16(13 * scale),
                    textColor = dialog_color_opacity(
                        theme.Light.text_secondary,
                        eased,
                    ),
                },
            )
            close_id := clay.ID("AboutClose")
            hovered := clay.PointerOver(close_id)
            if clay.UI(close_id)(
            {
                layout = clay.LayoutConfig {
                    sizing = clay.Sizing {
                        width = clay.SizingFixed(88 * scale),
                        height = clay.SizingFixed(32 * scale),
                    },
                    childAlignment = clay.ChildAlignment {
                        x = .Center,
                        y = .Center,
                    },
                },
                backgroundColor = dialog_color_opacity(
                    hovered ? theme.Light.accent_hover : theme.Light.accent,
                    eased,
                ),
                cornerRadius = clay.CornerRadiusAll(6 * scale),
            },
            ) {
                clay.Text(
                    "Close",
                    clay.TextElementConfig {
                        fontSize = u16(13 * scale),
                        textColor = dialog_color_opacity(
                            theme.Light.on_accent,
                            eased,
                        ),
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

dialog_color_opacity :: proc(color: clay.Color, opacity: f32) -> clay.Color {
    result := color
    result.a *= opacity
    return result
}
