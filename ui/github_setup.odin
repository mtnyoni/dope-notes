package ui

import config "../appconfig"
import theme "../theme"
import "core:c"
import "core:strings"
import clay "shared:clay"
import sdl "vendor:sdl3"

GithubSetupPhase :: enum {Welcome, Authorizing, Repository, Busy}
GithubSetupRequest :: enum {None, SignIn, Connect, Create}
GithubSetupState :: struct {
    reset_requested: bool,
    open: bool,
    just_opened: bool,
    phase: GithubSetupPhase,
    request: GithubSetupRequest,
    repository: [160]u8,
    repository_length: int,
    branch: [80]u8,
    branch_length: int,
    branch_initialized: bool,
    selected_field: int,
    user_code: [32]u8,
    error: [1024]u8,
}

github_setup_handle_event :: proc(setup: ^GithubSetupState, event: ^sdl.Event) {
    if setup == nil || !setup.open || setup.phase != .Repository {return}
    buffer := setup.selected_field == 0 ? setup.repository[:] : setup.branch[:]
    length := setup.selected_field == 0 ? &setup.repository_length : &setup.branch_length
    if event.type == .KEY_DOWN {
        if event.key.key == sdl.K_TAB {setup.selected_field = 1 - setup.selected_field}
        if event.key.key == sdl.K_BACKSPACE && length^ > 0 {
            length^ -= 1
            buffer[length^] = 0
        }
    }
    if event.type == .TEXT_INPUT {
        text := string(event.text.text)
        for byte in transmute([]u8)text {
            if byte >= 33 && byte < 127 && length^ < len(buffer)-1 {
                buffer[length^] = byte
                length^ += 1
            }
        }
    }
}

GithubSetupButton :: proc(name, label: string) -> bool {
    id := clay.ID(name)
    hovered := clay.PointerOver(id)
    clicked := false
    if clay.UI(id)({
        layout = clay.LayoutConfig {
            sizing = clay.Sizing {width = clay.SizingGrow(), height = clay.SizingFixed(32)},
            childAlignment = clay.ChildAlignment {x = .Center, y = .Center},
        },
        backgroundColor = hovered ? theme.Light.accent_hover : theme.Light.accent,
        cornerRadius = clay.CornerRadiusAll(6),
    }) {
        clay.Text(label, clay.TextElementConfig {fontSize = 13, textColor = theme.Light.on_accent})
        clicked = hovered && clay.GetPointerState().state == .PressedThisFrame
    }
    return clicked
}

GithubSetupField :: proc(name, label, value: string, selected: bool) -> bool {
    clay.Text(label, clay.TextElementConfig {fontSize = 12, textColor = theme.Light.text_secondary})
    id := clay.ID(name)
    hovered := clay.PointerOver(id)
    if clay.UI(id)({
        layout = clay.LayoutConfig {
            sizing = clay.Sizing {width = clay.SizingGrow(), height = clay.SizingFixed(32)},
            padding = clay.Padding {left = 8, right = 8},
            childAlignment = clay.ChildAlignment {y = .Center},
        },
        clip = clay.ClipElementConfig {horizontal = true, vertical = true},
        backgroundColor = theme.White,
        border = clay.BorderElementConfig {
            width = clay.BorderWidth {left = 1, right = 1, top = 1, bottom = 1},
            color = selected ? theme.Light.accent : theme.Light.border,
        },
        cornerRadius = clay.CornerRadiusAll(4),
    }) {
        clay.Text(value == "" ? " " : value, clay.TextElementConfig {fontSize = 13, textColor = theme.Light.text, wrapMode = .None})
    }
    return hovered && clay.GetPointerState().state == .PressedThisFrame
}

GithubSetupDialog :: proc(setup: ^GithubSetupState, maximized: bool) {
    if setup == nil || !setup.open {return}
    if !setup.branch_initialized {
        default_branch: string = config.GITHUB_SYNC_BRANCH
        copy(setup.branch[:], transmute([]u8)default_branch)
        setup.branch_length = len(default_branch)
        setup.branch_initialized = true
    }
    if clay.UI(clay.ID("GithubSetupOverlay"))({
        layout = clay.LayoutConfig {
            sizing = clay.Sizing {width = clay.SizingGrow(), height = clay.SizingGrow()},
            childAlignment = clay.ChildAlignment {x = .Center, y = .Center},
            padding = clay.PaddingAll(20),
        },
        floating = clay.FloatingElementConfig {
            attachTo = .Root,
            attachment = clay.FloatingAttachPoints {element = .CenterCenter, parent = .CenterCenter},
            zIndex = 100,
        },
        backgroundColor = clay.Color {0, 0, 0, 70},
        cornerRadius = clay.CornerRadiusAll(maximized ? 0 : 12),
    }) {
        if clay.UI(clay.ID("GithubSetupDialog"))({
            layout = clay.LayoutConfig {
                sizing = clay.Sizing {width = clay.SizingFixed(400), height = clay.SizingFit()},
                layoutDirection = .TopToBottom,
                padding = clay.PaddingAll(24),
                childGap = 12,
            },
            backgroundColor = theme.Light.surface,
            cornerRadius = clay.CornerRadiusAll(12),
            border = clay.BorderElementConfig {
                width = clay.BorderWidth {left = 1, right = 1, top = 1, bottom = 1},
                color = theme.Light.border,
            },
        }) {
            clay.Text("Sync with GitHub", clay.TextElementConfig {fontSize = 20, textColor = theme.Light.text})
            switch setup.phase {
            case .Welcome:
                clay.Text("Sign in to GitHub to sync your notes across your devices.", clay.TextElementConfig {fontSize = 14, textColor = theme.Light.text_secondary})
                if GithubSetupButton("GithubSignIn", "Sign in with GitHub") {setup.request = .SignIn}
            case .Busy:
                clay.Text("Connecting to GitHub...", clay.TextElementConfig {fontSize = 14, textColor = theme.Light.text_secondary})
            case .Authorizing:
                clay.Text("Enter this code at github.com/login/device", clay.TextElementConfig {fontSize = 14, textColor = theme.Light.text_secondary})
                clay.Text(string(cstring(&setup.user_code[0])), clay.TextElementConfig {fontSize = 24, textColor = theme.Light.text})
                if GithubSetupButton("GithubBrowser", "Open GitHub") {_ = sdl.OpenURL("https://github.com/login/device")}
                if GithubSetupButton("GithubCopyCode", "Copy code") {_ = sdl.SetClipboardText(cstring(&setup.user_code[0]))}
                clay.Text("Waiting for authorization...", clay.TextElementConfig {fontSize = 12, textColor = theme.Light.text_secondary})
            case .Repository:
                clay.Text("Use a private repository dedicated to your notes. Create a new one to start with these local notes.", clay.TextElementConfig {fontSize = 13, textColor = theme.Light.text_secondary})
                if GithubSetupField("GithubRepository", "Repository (owner/name)", string(setup.repository[:setup.repository_length]), setup.selected_field == 0) {setup.selected_field = 0}
                if GithubSetupField("GithubBranch", "Branch", string(setup.branch[:setup.branch_length]), setup.selected_field == 1) {setup.selected_field = 1}
                if GithubSetupButton("GithubConnect", "Connect repository") {setup.request = .Connect}
                if GithubSetupButton("GithubCreate", "Create private repository") {setup.request = .Create}
                if GithubSetupButton("GithubSignInAgain", "Use another GitHub account") {setup.request = .SignIn}
            }
            if setup.error[0] != 0 {
                clay.Text(string(cstring(&setup.error[0])), clay.TextElementConfig {fontSize = 12, textColor = theme.Light.text_secondary})
            }
            if GithubSetupButton("GithubSetupClose", "Cancel") {setup.open = false}
        }
        if !setup.just_opened && clay.GetPointerState().state == .PressedThisFrame &&
           !clay.PointerOver(clay.ID("GithubSetupDialog")) {setup.open = false}
    }
    setup.just_opened = false
}
