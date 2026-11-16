package ui

import assets "../assets"
import theme "../theme"
import "core:strings"
import clay "shared:clay"

TOAST_DURATION_SECONDS :: 3.0
TOAST_WIDTH :: 240
TOAST_FONT_SIZE :: 11

ToastState :: struct {
    message:           string,
    remaining_seconds: f32,
    icon: assets.Icon,
}

show_toast :: proc(toast: ^ToastState, message: string, icon: assets.Icon = .CircleCheck) {
    if toast == nil {return}
    delete(toast.message)
    toast.message = strings.clone(message)
    toast.remaining_seconds = TOAST_DURATION_SECONDS
    toast.icon = icon
}

destroy_toast :: proc(toast: ^ToastState) {
    delete(toast.message)
    toast^ = {}
}

Toast :: proc(toast: ^ToastState, delta_seconds: f32, ui_assets: ^assets.Manager) {
    if toast == nil || toast.remaining_seconds <= 0 {return}
    toast.remaining_seconds = max(0, toast.remaining_seconds - delta_seconds)
    if toast.remaining_seconds <= 0 {
        destroy_toast(toast)
        return
    }
    if clay.UI(clay.ID("Toast"))(
    {
        layout = clay.LayoutConfig {
            layoutDirection = .LeftToRight,
            childAlignment = clay.ChildAlignment {y = .Center},
            childGap = 8,
            sizing = clay.Sizing {
                width = clay.SizingFixed(TOAST_WIDTH),
                height = clay.SizingFit(),
            },
            padding = clay.Padding {
                left = 16,
                right = 16,
                top = 12,
                bottom = 12,
            },
        },
        floating = clay.FloatingElementConfig {
            attachTo = .Root,
            attachment = clay.FloatingAttachPoints {
                element = .RightBottom,
                parent = .RightBottom,
            },
            offset = clay.Vector2{-20, -20},
            pointerCaptureMode = .Passthrough,
            zIndex = 110,
        },
        backgroundColor = theme.Light.surface,
        cornerRadius = clay.CornerRadiusAll(8),
        border = clay.BorderElementConfig {
            width = clay.BorderWidth{left = 1, right = 1, top = 1, bottom = 1},
            color = theme.Light.border,
        },
    },
    ) {
        if texture := assets.get(ui_assets, toast.icon); texture != nil {
            if clay.UI()({
                layout = clay.LayoutConfig {
                    sizing = clay.Sizing {width = clay.SizingFixed(16), height = clay.SizingFixed(16)},
                },
                image = clay.ImageElementConfig {imageData = rawptr(texture)},
            }) {}
        }
        clay.Text(
            toast.message,
            clay.TextElementConfig {
                fontSize = TOAST_FONT_SIZE,
                textColor = theme.Light.text,
            },
        )
    }
}
