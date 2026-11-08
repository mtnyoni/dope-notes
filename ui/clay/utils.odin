package ui
import "core:c"
import clay "shared:clay"
import font "ui/font"

errorHandler :: proc "c" (errorData: clay.ErrorData) {
	if (errorData.errorType == clay.ErrorType.DuplicateId) {
		// etc
	}
}

measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	face := cast(^font.Font)userData
	width, height: c.int
	if font.measure(
		   face,
		   cast([^]u8)text.chars,
		   text.length,
		   c.int(config.fontSize),
		   &width,
		   &height,
	   ) ==
	   0 {
		return {}
	}
	return {f32(width), f32(height)}
}
