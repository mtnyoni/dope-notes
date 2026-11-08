package ui

import "core:c"
import "core:math"
import "core:strings"
import clay "shared/clay/bindings/odin/clay-odin"
import font "ui/font"
import sdl "vendor:sdl3"

Cached_Text :: struct {
	label:         string,
	pixel_size:    i32,
	texture:       ^sdl.Texture,
	width, height: i32,
}

Mask_Key :: struct {
	width, height: i32,
	radius:        [4]f32,
	border_width:  [4]f32,
	is_border:     bool,
}

Cached_Mask :: struct {
	key:     Mask_Key,
	texture: ^sdl.Texture,
}

Clay_Renderer :: struct {
	font:  ^font.Font,
	texts: [dynamic]Cached_Text,
	masks: [dynamic]Cached_Mask,
}

destroy_clay_renderer :: proc(state: ^Clay_Renderer) {
	for entry in state.texts {
		sdl.DestroyTexture(entry.texture)
		delete(entry.label)
	}
	for entry in state.masks {
		sdl.DestroyTexture(entry.texture)
	}
	delete(state.texts)
	delete(state.masks)
}

pixel_rect :: proc(box: clay.BoundingBox, scale_x, scale_y: f32) -> sdl.FRect {
	x := math.round(box.x * scale_x)
	y := math.round(box.y * scale_y)
	right := math.round((box.x + box.width) * scale_x)
	bottom := math.round((box.y + box.height) * scale_y)
	return {x, y, right - x, bottom - y}
}

radius_array :: proc(radius: clay.CornerRadius, scale: f32) -> [4]f32 {
	return {
		radius.topLeft * scale,
		radius.topRight * scale,
		radius.bottomLeft * scale,
		radius.bottomRight * scale,
	}
}

set_color :: proc(renderer: ^sdl.Renderer, color: clay.Color) {
	assert(
		sdl.SetRenderDrawColor(renderer, u8(color[0]), u8(color[1]), u8(color[2]), u8(color[3])),
	)
}

render_clay :: proc(
	state: ^Clay_Renderer,
	renderer: ^sdl.Renderer,
	commands: ^clay.ClayArray(clay.RenderCommand),
	scale_x, scale_y: f32,
) {
	for i in 0 ..< commands.length {
		command := clay.RenderCommandArray_Get(commands, i)
		rect := pixel_rect(command.boundingBox, scale_x, scale_y)
		if rect.w <= 0 || rect.h <= 0 do continue

		#partial switch command.commandType {
		case .Rectangle:
			data := command.renderData.rectangle
			radius := radius_array(data.cornerRadius, min(scale_x, scale_y))
			if radius == ([4]f32{}) {
				set_color(renderer, data.backgroundColor)
				assert(sdl.RenderFillRect(renderer, &rect))
			} else {
				key := Mask_Key{i32(rect.w), i32(rect.h), radius, {}, false}
				texture := get_mask(state, renderer, key)
				draw_tinted(renderer, texture, rect, data.backgroundColor)
			}
		case .Border:
			data := command.renderData.border
			key := Mask_Key {
				width        = i32(rect.w),
				height       = i32(rect.h),
				radius       = radius_array(data.cornerRadius, min(scale_x, scale_y)),
				border_width = {
					f32(data.width.left) * scale_x,
					f32(data.width.right) * scale_x,
					f32(data.width.top) * scale_y,
					f32(data.width.bottom) * scale_y,
				},
				is_border    = true,
			}
			texture := get_mask(state, renderer, key)
			draw_tinted(renderer, texture, rect, data.color)
		case .Text:
			data := command.renderData.text
			label := string(data.stringContents.chars[:data.stringContents.length])
			pixel_size := max(1, i32(math.round(f32(data.fontSize) * scale_y)))
			entry := get_text(state, renderer, label, pixel_size)
			if entry != nil {
				dst := sdl.FRect{rect.x, rect.y, f32(entry.width), f32(entry.height)}
				draw_tinted(renderer, entry.texture, dst, data.textColor)
			}
		case .Image:
			texture := cast(^sdl.Texture)command.renderData.image.imageData
			if texture != nil do assert(sdl.RenderTexture(renderer, texture, nil, &rect))
		}
	}
}

draw_tinted :: proc(
	renderer: ^sdl.Renderer,
	texture: ^sdl.Texture,
	dst: sdl.FRect,
	color: clay.Color,
) {
	assert(sdl.SetTextureColorMod(texture, u8(color[0]), u8(color[1]), u8(color[2])))
	assert(sdl.SetTextureAlphaMod(texture, u8(color[3])))
	target := dst
	assert(sdl.RenderTexture(renderer, texture, nil, &target))
}

get_text :: proc(
	state: ^Clay_Renderer,
	renderer: ^sdl.Renderer,
	label: string,
	pixel_size: i32,
) -> ^Cached_Text {
	for &entry in state.texts {
		if entry.pixel_size == pixel_size && entry.label == label do return &entry
	}
	pixels: ^u8
	width, height: c.int
	if font.rasterize(
		   state.font,
		   raw_data(label),
		   c.int(len(label)),
		   pixel_size,
		   &pixels,
		   &width,
		   &height,
	   ) ==
	   0 {
		return nil
	}
	defer font.free_bitmap(pixels)
	texture := sdl.CreateTexture(renderer, .RGBA32, .STATIC, width, height)
	assert(texture != nil)
	assert(sdl.UpdateTexture(texture, nil, pixels, width * 4))
	assert(sdl.SetTextureBlendMode(texture, sdl.BLENDMODE_BLEND))
	assert(sdl.SetTextureScaleMode(texture, .LINEAR))
	append(&state.texts, Cached_Text{strings.clone(label), pixel_size, texture, width, height})
	return &state.texts[len(state.texts) - 1]
}

inside_rounded :: proc(x, y: f32, width, height: f32, radii: [4]f32) -> bool {
	if x < 0 || y < 0 || x >= width || y >= height do return false
	limit := min(width, height) / 2
	tl, tr := min(radii[0], limit), min(radii[1], limit)
	bl, br := min(radii[2], limit), min(radii[3], limit)
	if x < tl && y < tl do return (x - tl) * (x - tl) + (y - tl) * (y - tl) <= tl * tl
	if x >= width - tr && y < tr do return (x - (width - tr)) * (x - (width - tr)) + (y - tr) * (y - tr) <= tr * tr
	if x < bl && y >= height - bl do return (x - bl) * (x - bl) + (y - (height - bl)) * (y - (height - bl)) <= bl * bl
	if x >= width - br && y >= height - br do return (x - (width - br)) * (x - (width - br)) + (y - (height - br)) * (y - (height - br)) <= br * br
	return true
}

get_mask :: proc(state: ^Clay_Renderer, renderer: ^sdl.Renderer, key: Mask_Key) -> ^sdl.Texture {
	for entry in state.masks {
		if entry.key == key do return entry.texture
	}
	pixels := make([]u8, int(key.width * key.height * 4), context.temp_allocator)
	inner_x, inner_y := key.border_width[0], key.border_width[2]
	inner_width := f32(key.width) - key.border_width[0] - key.border_width[1]
	inner_height := f32(key.height) - key.border_width[2] - key.border_width[3]
	inner_radii := [4]f32 {
		max(0, key.radius[0] - max(key.border_width[0], key.border_width[2])),
		max(0, key.radius[1] - max(key.border_width[1], key.border_width[2])),
		max(0, key.radius[2] - max(key.border_width[0], key.border_width[3])),
		max(0, key.radius[3] - max(key.border_width[1], key.border_width[3])),
	}
	for y in 0 ..< key.height {
		for x in 0 ..< key.width {
			coverage: u8 = 0
			for sy in 0 ..< 4 {
				for sx in 0 ..< 4 {
					px := f32(x) + (f32(sx) + 0.5) / 4
					py := f32(y) + (f32(sy) + 0.5) / 4
					inside := inside_rounded(px, py, f32(key.width), f32(key.height), key.radius)
					if key.is_border && inside {
						inside = !inside_rounded(
							px - inner_x,
							py - inner_y,
							inner_width,
							inner_height,
							inner_radii,
						)
					}
					if inside do coverage += 1
				}
			}
			offset := int((y * key.width + x) * 4)
			pixels[offset] = 255
			pixels[offset + 1] = 255
			pixels[offset + 2] = 255
			pixels[offset + 3] = u8(u16(coverage) * 255 / 16)
		}
	}
	texture := sdl.CreateTexture(renderer, .RGBA32, .STATIC, key.width, key.height)
	assert(texture != nil)
	assert(sdl.UpdateTexture(texture, nil, raw_data(pixels), key.width * 4))
	assert(sdl.SetTextureBlendMode(texture, sdl.BLENDMODE_BLEND))
	assert(sdl.SetTextureScaleMode(texture, .LINEAR))
	append(&state.masks, Cached_Mask{key, texture})
	return texture
}
