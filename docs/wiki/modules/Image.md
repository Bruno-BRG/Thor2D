# thor2d.Image

LOVE equivalent: `love.image`. Sources: `image.odin`.

## Description

CPU RGBA8 `Image_Data`: `New_Image_Data/From_Bytes/From_Buffer`, `Get/Set_Image_Pixel`, `Paste_Image` (LOVE `ImageData:paste`, clipped), `Map_Pixel` (LOVE `ImageData:mapPixel`), `Encode_Image_PNG` (LOVE `ImageData:encode("png")`, pure-CPU memory encoder), `Create_Texture_From_Image_Data`, `Export_Image_PNG`, `Capture_Screenshot`.

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Graphics](Graphics.md)

## Compressed images (v0.9)

LOVE equivalent: `love.image.isCompressed` / `love.image.newCompressedData`.
Source: `image.odin`.

`Is_Compressed_Image` sniffs magic bytes for GPU-compressed containers only
(DDS `DDS `, KTX1/KTX2, PKM `PKM `, ASTC, PVR v3) — PNG/JPEG return false by
design, matching LOVE's "GPU-compressed" meaning. `Load_Compressed_Texture`
accepts only those containers (else `Error.Invalid_Data`) and loads through
the extension-driven raylib path (DXT/ETC/ASTC formats); a recognized
container the backend cannot realize returns `Error.Unsupported`, never a
fake texture. Headless reports `Error.Backend_Initialization_Failed`.
