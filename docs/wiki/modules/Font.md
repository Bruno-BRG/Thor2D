# thor2d.Font

LOVE equivalent: `love.font`. Sources: `graphics.odin`, `graphics_state.odin`.

## Description

`Load_Font/Unload_Font`, `Draw_Text_Font/Measure_Text_Font`, cached `Text` objects, `Set_Font/Get_Font` global (v0.8). No rasterizer/GlyphData layer.

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## Metrics and line height (v0.10)

LOVE equivalents: `Font:getAscent/getDescent/getBaseline/getHeight`,
`Font:getLineHeight/setLineHeight`, `Font:hasGlyphs`, `Font:getDPIScale`.
Source: `graphics.odin` (backed by `Font_Entry` in `internal/raylib/backend.odin`).

- `Font_Ascent(ctx, font, size)` / `Font_Descent(ctx, font, size)` /
  `Font_Baseline(ctx, font, size)` — LOVE `getAscent/getDescent/getBaseline`.
  Approximation (documented in code): raylib's `Font` exposes only `baseSize`
  plus the glyph table — no TrueType ascent/descent tables — so metrics scale
  proportionally with size (ascent/baseline `0.8em`, descent `0.2em`;
  ascent + descent == 1em). Handles are backend-validated (`Font{}` is the
  always-present default font, answered from CPU ratios even headless);
  unknown handles and non-positive sizes report `0`.
- `Font_Line_Height(ctx, font, size)` — LOVE `getHeight`: the line advance in
  pixels, `size` times the stored multiplier.
- `Font_Set_Line_Height(ctx, font, height)` / `Font_Get_Line_Height(ctx, font)`
  — LOVE `setLineHeight/getLineHeight` (multiplier, `1.0` default). Stored
  per font on the backend entry (the default font's lives on the backend).
  Honored by `Font_Line_Height`, by `Measure_Text_Layout` (via the current
  font) and by multiline `Text` draw advance; headless sets are no-ops.
- `Font_Has_Glyphs(ctx, font, text)` — LOVE `hasGlyphs` (plain-string form).
  Best-effort codepoint coverage: windowed backends scan the loaded glyph
  table (shaping-only coverage is not detected); headless, only the default
  font answers and assumes ASCII. Empty text is `true`, invalid UTF-8 is `false`.
- `Font_DPI_Scale(ctx, font)` — LOVE `getDPIScale`. Thor2D rasterizes once
  (base size 32) and scales at draw, so every font shares the window scale:
  returns `Window_DPI_Scale(ctx).X` (`1.0` headless, `0` on unknown handles).

Per-text fonts: `Text_Font(ctx, text)` / `Text_Set_Font(ctx, text, font)` —
LOVE `Text:getFont/setFont` (`Font{}` selects the default font; see
[Graphics](Graphics.md) for `Text_Add`/`Text_Addf`/`Text_Clear`).

```odin
thor2d.Font_Set_Line_Height(ctx, font, 1.5)
advance := thor2d.Font_Line_Height(ctx, font, 16) // 24
ok := thor2d.Font_Has_Glyphs(ctx, font, "ABC")
```

## See Also

[Graphics](Graphics.md)

## Image fonts (v0.9)

LOVE equivalent: `love.graphics.newImageFont(image, glyphs)`. Source: `imagefont.odin`.

CPU-side `Image_Font`: the glyphs run left-to-right in one image row with
cell width = image.width / len(glyphs). `Load_Image_Font` clones the ASCII
glyph string and uploads a texture when a backend exists (headless fonts keep
CPU data only: `Measure_Text_Image_Font` and `Unload_Image_Font` work,
`Draw_Text_Image_Font` no-ops). `Image_Font_Invalid` reports missing glyph
data. Unknown text bytes advance one blank cell; `\n` starts a new line.
Rejected loudly with `Error.Invalid_Data`: empty/non-ASCII glyphs,
non-divisible widths. The raylib `LoadFontFromImage` path is deliberately not
used: it assumes sequential codepoints from a first character and cannot
represent arbitrary LOVE glyph strings.
