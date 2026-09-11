# thor2d.Data

`thor2d.Data` is the binary/data utility layer. It has no window dependency and
is safe to use in headless tests. Every returned `Byte_Buffer` or
`File_Data` owns memory; call its matching destroy procedure when finished.

## Ownership and views

`New_Byte_Buffer(capacity)` allocates writable storage. `Byte_Buffer_Bytes` is
the live byte slice; `Byte_Buffer_Copy` makes an owned copy and
`Byte_Buffer_Slice` makes a bounded view. `New_Data_View` and
`Byte_Buffer_View` expose read-only byte ranges without copying. A view is
invalid after its owner is destroyed or resized.

`File_Data_View(filesystem, path)` reads a source file and returns an owned
file-data object. Use `File_Data_Bytes` to access it and
`Destroy_File_Data` to release it. File errors are returned rather than an
empty fake buffer.

## Encoding and hashing

| Operation | Behavior |
| --- | --- |
| `Encode_Base64` / `Decode_Base64` | Standard Base64; malformed input returns `.Invalid_Data`. |
| `Encode_Base64_Lines` | MIME-style newlines; `line_length <= 0` is `.Invalid_Data`. |
| `Encode_Hex` / `Decode_Hex` | Lowercase hexadecimal output; odd or invalid input is rejected. |
| `Hash_Data` / `Hash_Hex` | Stable SHA-256 bytes or lowercase hexadecimal text. |
| `Encode_JSON` / `Decode_JSON` | Odin JSON representation; decode validates the destination. |
| `Encode_CBOR` / `Decode_CBOR` | Binary CBOR representation for supported Odin values. |

Decode procedures return an error and do not promise a usable partial result on
malformed data. Destroy buffers returned by successful encode/compress calls.

## Fixed-width packing

`Pack_U16`, `Pack_U32`, `Pack_U64`, `Pack_I32` and `Pack_F32` write little-endian
values. `Unpack_*` requires enough bytes and returns `.Invalid_Data` otherwise.
`Get_Packed_Size` and the type-specific size procedures report the exact byte
count. This is intentionally a fixed LE subset, not Lua/LOVE format strings.

```odin
packed := thor2d.Pack_U32(0x12345678)
defer thor2d.Destroy_Byte_Buffer(&packed)
value, unpack_err := thor2d.Unpack_U32(packed.Bytes[:])
assert(unpack_err == .None && value == 0x12345678)
```

## Compression

`Compress_Data` / `Decompress_Data` support ZLIB, GZIP, raw DEFLATE and LZ4
formats. `Compress_With_Level` accepts levels 0–9 for zlib-family formats;
values are clamped. LZ4 ignores the level because its bundled backend has no
level setting. A wrong format, corrupt stream or insufficient data returns an
error. Compression output owns its buffer.

## See also

[Filesystem](Filesystem.md), [Project](Project.md), and the
[complete API reference](../Complete_API.md).
