package theme

import clay "shared:clay"

// Clay uses RGBA channels from 0 to 255. All palette colors are opaque.
White :: clay.Color{255, 255, 255, 255} // #FFFFFF
Black :: clay.Color{0, 0, 0, 255} // #000000

Cyan_50 :: clay.Color{236, 254, 255, 255} // #ECFEFF
Cyan_100 :: clay.Color{207, 250, 254, 255} // #CFFAFE
Cyan_200 :: clay.Color{165, 243, 252, 255} // #A5F3FC
Cyan_300 :: clay.Color{103, 232, 249, 255} // #67E8F9
Cyan_400 :: clay.Color{34, 211, 238, 255} // #22D3EE
Cyan_500 :: clay.Color{6, 182, 212, 255} // #06B6D4
Cyan_600 :: clay.Color{8, 145, 178, 255} // #0891B2
Cyan_700 :: clay.Color{14, 116, 144, 255} // #0E7490
Cyan_800 :: clay.Color{21, 94, 117, 255} // #155E75
Cyan_900 :: clay.Color{22, 78, 99, 255} // #164E63
Cyan_950 :: clay.Color{8, 51, 68, 255} // #083344

Gray_50 :: clay.Color{246, 248, 248, 255} // #F6F8F8
Gray_100 :: clay.Color{238, 240, 241, 255} // #EEF0F1
Gray_200 :: clay.Color{218, 223, 226, 255} // #DADFE2
Gray_300 :: clay.Color{192, 200, 205, 255} // #C0C8CD
Gray_400 :: clay.Color{147, 160, 169, 255} // #93A0A9
Gray_500 :: clay.Color{108, 125, 137, 255} // #6C7D89
Gray_600 :: clay.Color{83, 96, 105, 255} // #536069
Gray_700 :: clay.Color{65, 76, 83, 255} // #414C53
Gray_800 :: clay.Color{45, 52, 57, 255} // #2D3439
Gray_900 :: clay.Color{29, 34, 37, 255} // #1D2225
Gray_950 :: clay.Color{18, 21, 23, 255} // #121517

// Semantic colors keep UI code independent of individual palette shades.
Theme :: struct {
	background:     clay.Color,
	surface:        clay.Color,
	surface_muted:  clay.Color,
	border:         clay.Color,
	text:           clay.Color,
	text_secondary: clay.Color,
	text_disabled:  clay.Color,
	accent:         clay.Color,
	accent_hover:   clay.Color,
	accent_pressed: clay.Color,
	on_accent:      clay.Color,
	selection:      clay.Color,
	focus:          clay.Color,
}

Light :: Theme {
	background     = Gray_100,
	surface        = White,
	surface_muted  = Gray_100,
	border         = Gray_200,
	text           = Gray_950,
	text_secondary = Gray_600,
	text_disabled  = Gray_400,
	accent         = Cyan_700,
	accent_hover   = Cyan_800,
	accent_pressed = Cyan_900,
	on_accent      = White,
	selection      = Cyan_100,
	focus          = Cyan_600,
}
