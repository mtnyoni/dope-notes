#include <ft2build.h>
#include FT_FREETYPE_H
#include <stdint.h>
#include <stdlib.h>

typedef struct {
  FT_Library library;
  FT_Face face;
} AppFont;

static uint32_t next_codepoint(const char **cursor, const char *end) {
  const unsigned char *p = (const unsigned char *)*cursor;
  uint32_t c = *p++;
  if (c < 0x80) {
    *cursor = (const char *)p;
    return c;
  }
  int extra = c < 0xe0 ? 1 : c < 0xf0 ? 2 : 3;
  c &= (1u << (6 - extra)) - 1;
  while (extra-- && (const char *)p < end)
    c = (c << 6) | (*p++ & 0x3f);
  *cursor = (const char *)p;
  return c;
}

AppFont *app_font_open(const char *path) {
  AppFont *font = calloc(1, sizeof(*font));
  if (!font)
    return NULL;
  if (FT_Init_FreeType(&font->library) ||
      FT_New_Face(font->library, path, 0, &font->face)) {
    if (font->library)
      FT_Done_FreeType(font->library);
    free(font);
    return NULL;
  }
  return font;
}

void app_font_close(AppFont *font) {
  if (!font)
    return;
  FT_Done_Face(font->face);
  FT_Done_FreeType(font->library);
  free(font);
}

static int set_size(AppFont *font, int pixel_size) {
  return font && pixel_size > 0 &&
         !FT_Set_Pixel_Sizes(font->face, 0, (FT_UInt)pixel_size);
}

int app_font_measure(AppFont *font, const char *text, int length,
                     int pixel_size, int *width, int *height) {
  if (!set_size(font, pixel_size) || !text || length < 0)
    return 0;
  const char *cursor = text;
  const char *end = text + length;
  FT_UInt previous = 0;
  FT_Pos advance = 0;
  while (cursor < end) {
    FT_UInt glyph = FT_Get_Char_Index(font->face, next_codepoint(&cursor, end));
    if (previous && glyph && FT_HAS_KERNING(font->face)) {
      FT_Vector kerning;
      FT_Get_Kerning(font->face, previous, glyph, FT_KERNING_DEFAULT, &kerning);
      advance += kerning.x;
    }
    if (!FT_Load_Glyph(font->face, glyph, FT_LOAD_DEFAULT))
      advance += font->face->glyph->advance.x;
    previous = glyph;
  }
  *width = (int)((advance + 63) >> 6);
  *height = (int)((font->face->size->metrics.height + 63) >> 6);
  return 1;
}

int app_font_rasterize(AppFont *font, const char *text, int length,
                       int pixel_size, unsigned char **pixels, int *width,
                       int *height) {
  if (!app_font_measure(font, text, length, pixel_size, width, height))
    return 0;
  if (*width <= 0 || *height <= 0)
    return 0;
  unsigned char *rgba = calloc((size_t)*width * (size_t)*height, 4);
  if (!rgba)
    return 0;
  const char *cursor = text;
  const char *end = text + length;
  FT_UInt previous = 0;
  FT_Pos pen = 0;
  int baseline = (int)((font->face->size->metrics.ascender + 63) >> 6);
  while (cursor < end) {
    FT_UInt glyph = FT_Get_Char_Index(font->face, next_codepoint(&cursor, end));
    if (previous && glyph && FT_HAS_KERNING(font->face)) {
      FT_Vector kerning;
      FT_Get_Kerning(font->face, previous, glyph, FT_KERNING_DEFAULT, &kerning);
      pen += kerning.x;
    }
    if (!FT_Load_Glyph(font->face, glyph, FT_LOAD_RENDER)) {
      FT_GlyphSlot slot = font->face->glyph;
      FT_Bitmap *bitmap = &slot->bitmap;
      int origin_x = (int)(pen >> 6) + slot->bitmap_left;
      int origin_y = baseline - slot->bitmap_top;
      for (int y = 0; y < (int)bitmap->rows; ++y) {
        int dest_y = origin_y + y;
        if (dest_y < 0 || dest_y >= *height)
          continue;
        const unsigned char *row = bitmap->buffer + y * bitmap->pitch;
        for (int x = 0; x < (int)bitmap->width; ++x) {
          int dest_x = origin_x + x;
          if (dest_x < 0 || dest_x >= *width)
            continue;
          unsigned char *dest = rgba + ((size_t)dest_y * *width + dest_x) * 4;
          dest[0] = dest[1] = dest[2] = 255;
          dest[3] = row[x];
        }
      }
      pen += slot->advance.x;
    }
    previous = glyph;
  }
  *pixels = rgba;
  return 1;
}

void app_font_free_bitmap(unsigned char *pixels) { free(pixels); }
