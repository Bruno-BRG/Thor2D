# thor2d.Data

LOVE equivalent: `love.data`. Sources: `data.odin`, `love_gaps.odin`.

## Description

Buffers, views, Base64/hex, hashes, JSON/CBOR, LZ4/ZLIB/GZIP/DEFLATE, fixed-width LE `Pack/Unpack` + `Get_Packed_Size` (no Lua format strings by design).

v0.10 additions: `Compress_With_Level(data, format, level)` — explicit zlib level (clamped 0–9) for ZLIB/GZIP/DEFLATE via `vendor:zlib`; LZ4 ignores the level (no level API in `vendor:compress/lz4`) but still round-trips through `Decompress_Data`. `Encode_Base64_Lines(data, line_length := 76)` — MIME-style `\n`-wrapped Base64 (strip newlines to recover the `Encode_Base64` form); `line_length <= 0` is `.Invalid_Data`.

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Filesystem](Filesystem.md)
