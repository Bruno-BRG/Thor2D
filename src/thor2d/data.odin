package thor2d

import "core:encoding/base64"
import "core:encoding/cbor"
import "core:encoding/hex"
import "core:encoding/json"
import "core:crypto/hash"
import "core:c"
import "core:reflect"
import lz4 "vendor:compress/lz4"
import zlib "vendor:zlib"

New_Byte_Buffer :: proc(data: []byte) -> Byte_Buffer {
	buffer := Byte_Buffer{}
	if len(data) > 0 {
		buffer.Bytes = make([dynamic]byte, len(data))
		copy(buffer.Bytes[:], data)
	}
	return buffer
}

Destroy_Byte_Buffer :: proc(buffer: ^Byte_Buffer) {
	if buffer != nil {
		delete(buffer.Bytes)
		buffer.Bytes = nil
	}
}

Byte_Buffer_Bytes :: proc(buffer: ^Byte_Buffer) -> []byte {
	if buffer == nil {
		return nil
	}
	return buffer.Bytes[:]
}

Byte_Buffer_Copy :: proc(buffer: ^Byte_Buffer) -> Byte_Buffer {
	if buffer == nil {
		return Byte_Buffer{}
	}
	return New_Byte_Buffer(buffer.Bytes[:])
}

Byte_Buffer_Slice :: proc(buffer: ^Byte_Buffer, start, length: int) -> (Byte_Buffer, Error) {
	if buffer == nil || start < 0 || length < 0 || start > len(buffer.Bytes) || length > len(buffer.Bytes)-start {
		return Byte_Buffer{}, .Invalid_Data
	}
	return New_Byte_Buffer(buffer.Bytes[start:start+length]), .None
}

New_Data_View :: proc(data: []byte) -> Data_View {
	return Data_View{Bytes = data}
}

Data_View_Bytes :: proc(view: ^Data_View) -> []byte {
	if view == nil {
		return nil
	}
	return view.Bytes
}

Byte_Buffer_View :: proc(buffer: ^Byte_Buffer, start, length: int) -> (Data_View, Error) {
	if buffer == nil || start < 0 || length < 0 || start > len(buffer.Bytes) || length > len(buffer.Bytes)-start {
		return Data_View{}, .Invalid_Data
	}
	return New_Data_View(buffer.Bytes[start:start+length]), .None
}

File_Data_View :: proc(data: ^File_Data) -> Data_View {
	if data == nil {
		return Data_View{}
	}
	return New_Data_View(data.Bytes[:])
}

// The binary helpers use little-endian encoding explicitly so project data is
// stable across desktop architectures. They intentionally cover primitive
// values; structured project data continues to use JSON/CBOR.
Pack_U16 :: proc(value: u16) -> Byte_Buffer {
	bytes := make([dynamic]byte, 2)
	bytes[0] = byte(value)
	bytes[1] = byte(value >> 8)
	return Byte_Buffer{Bytes = bytes}
}

Pack_U32 :: proc(value: u32) -> Byte_Buffer {
	bytes := make([dynamic]byte, 4)
	for i := 0; i < 4; i += 1 {
		bytes[i] = byte(value >> (u32(i) * 8))
	}
	return Byte_Buffer{Bytes = bytes}
}

Pack_U64 :: proc(value: u64) -> Byte_Buffer {
	bytes := make([dynamic]byte, 8)
	for i := 0; i < 8; i += 1 {
		bytes[i] = byte(value >> (u64(i) * 8))
	}
	return Byte_Buffer{Bytes = bytes}
}

Pack_I32 :: proc(value: i32) -> Byte_Buffer {
	return Pack_U32(cast(u32)value)
}

Pack_F32 :: proc(value: f32) -> Byte_Buffer {
	return Pack_U32(transmute(u32)value)
}

Unpack_U16 :: proc(data: []byte) -> (u16, Error) {
	if len(data) < 2 {
		return 0, .Invalid_Data
	}
	return u16(data[0]) | (u16(data[1]) << 8), .None
}

Unpack_U32 :: proc(data: []byte) -> (u32, Error) {
	if len(data) < 4 {
		return 0, .Invalid_Data
	}
	value: u32
	for i := 0; i < 4; i += 1 {
		value |= u32(data[i]) << (u32(i) * 8)
	}
	return value, .None
}

Unpack_U64 :: proc(data: []byte) -> (u64, Error) {
	if len(data) < 8 {
		return 0, .Invalid_Data
	}
	value: u64
	for i := 0; i < 8; i += 1 {
		value |= u64(data[i]) << (u64(i) * 8)
	}
	return value, .None
}

Unpack_I32 :: proc(data: []byte) -> (i32, Error) {
	value, err := Unpack_U32(data)
	return cast(i32)value, err
}

Unpack_F32 :: proc(data: []byte) -> (f32, Error) {
	value, err := Unpack_U32(data)
	return transmute(f32)value, err
}

File_Data_Bytes :: proc(data: ^File_Data) -> []byte {
	if data == nil {
		return nil
	}
	return data.Bytes[:]
}

Destroy_File_Data :: proc(data: ^File_Data) {
	if data != nil {
		delete(data.Bytes)
		delete(data.Path)
		data.Bytes = nil
		data.Path = ""
	}
}

Encode_Base64 :: proc(data: []byte) -> (string, Error) {
	encoded, err := base64.encode(data)
	if err != nil {
		return "", .Serialization_Failed
	}
	return encoded, .None
}

Decode_Base64 :: proc(value: string) -> (Byte_Buffer, Error) {
	decoded, err := base64.decode(value)
	if err != nil {
		return Byte_Buffer{}, .Invalid_Data
	}
	buffer := New_Byte_Buffer(decoded)
	delete(decoded)
	return buffer, .None
}

Encode_Hex :: proc(data: []byte) -> (string, Error) {
	encoded, err := hex.encode(data)
	if err != nil {
		return "", .Serialization_Failed
	}
	return string(encoded), .None
}

Decode_Hex :: proc(value: string) -> (Byte_Buffer, Error) {
	decoded, ok := hex.decode(transmute([]byte)value)
	if !ok {
		return Byte_Buffer{}, .Invalid_Data
	}
	buffer := New_Byte_Buffer(decoded)
	delete(decoded)
	return buffer, .None
}

Hash_Data :: proc(algorithm: Hash_Algorithm, data: []byte) -> (Byte_Buffer, Error) {
	native: hash.Algorithm
	switch algorithm {
	case .MD5: native = .Insecure_MD5
	case .SHA1: native = .Insecure_SHA1
	case .SHA224: native = .SHA224
	case .SHA256: native = .SHA256
	case .SHA384: native = .SHA384
	case .SHA512: native = .SHA512
	}
	digest := hash.hash_bytes(native, data)
	buffer := New_Byte_Buffer(digest)
	delete(digest)
	return buffer, .None
}

Hash_Hex :: proc(algorithm: Hash_Algorithm, data: []byte) -> (string, Error) {
	digest, err := Hash_Data(algorithm, data)
	if err != .None {
		return "", err
	}
	defer Destroy_Byte_Buffer(&digest)
	return Encode_Hex(digest.Bytes[:])
}

Encode_JSON :: proc(value: any) -> (Byte_Buffer, Error) {
	// Odin's JSON encoder intentionally rejects pointer values. Public Thor2D
	// APIs commonly receive pointers to project/resource records, so unwrap
	// one typed pointer while preserving the encoder's normal type validation.
	json_value := value
	if value != nil {
		ti := reflect.type_info_base(type_info_of(value.id))
		if pointer, ok := ti.variant.(reflect.Type_Info_Pointer); ok {
			if pointer.elem == nil || value.data == nil || (^rawptr)(value.data)^ == nil {
				return Byte_Buffer{}, .Serialization_Failed
			}
			json_value = any{(^rawptr)(value.data)^, pointer.elem.id}
		}
	}
	data, err := json.marshal(json_value)
	if err != nil {
		return Byte_Buffer{}, .Serialization_Failed
	}
	buffer := New_Byte_Buffer(data)
	delete(data)
	return buffer, .None
}

Decode_JSON :: proc(data: []byte, value: ^$T) -> Error {
	if err := json.unmarshal(data, value); err != nil {
		return .Serialization_Failed
	}
	return .None
}

Encode_CBOR :: proc(value: any) -> (Byte_Buffer, Error) {
	data, err := cbor.marshal(value)
	if err != nil {
		return Byte_Buffer{}, .Serialization_Failed
	}
	buffer := New_Byte_Buffer(data)
	delete(data)
	return buffer, .None
}

Decode_CBOR :: proc(data: []byte, value: ^$T) -> Error {
	if err := cbor.unmarshal(data, value); err != nil {
		return .Serialization_Failed
	}
	return .None
}

// Thor2D stores the original size in the first eight bytes of compressed
// blocks. This makes the safe one-shot decoders usable without trusting an
// allocation size supplied by untrusted input.
compressed_with_size :: proc(format: Compression_Format, data: []byte, capacity: int) -> (Compressed_Data, Error) {
	if capacity <= 0 {
		return Compressed_Data{}, .Compression_Failed
	}
	output := make([dynamic]byte, 8+capacity)
	size := u64(len(data))
	for i := 0; i < 8; i += 1 {
		output[i] = byte(size >> (u64(i) * 8))
	}

	compressed := 0
	switch format {
	case .LZ4:
		if len(data) > 0 {
			compressed = int(lz4.compress_default(&data[0], &output[8], c.int(len(data)), c.int(capacity)))
		}
	case .ZLIB:
		if len(data) > 0 {
			out_size := zlib.uLongf(capacity)
			status := zlib.compress2(&output[8], &out_size, &data[0], zlib.uLong(len(data)), zlib.DEFAULT_COMPRESSION)
			if status != zlib.OK {
				delete(output)
				return Compressed_Data{}, .Compression_Failed
			}
			compressed = int(out_size)
		}
	case .GZIP, .DEFLATE:
		if len(data) > 0 {
			window_bits := 15
			if format == .GZIP {
				window_bits = 31
			} else {
				window_bits = -15
			}
			stream := zlib.z_stream{}
			if zlib.deflateInit2(&stream, zlib.DEFAULT_COMPRESSION, zlib.DEFLATED, c.int(window_bits), 8, zlib.DEFAULT_STRATEGY) != zlib.OK {
				delete(output)
				return Compressed_Data{}, .Compression_Failed
			}
			stream.next_in = &data[0]
			stream.avail_in = zlib.uInt(len(data))
			stream.next_out = &output[8]
			stream.avail_out = zlib.uInt(capacity)
			status := zlib.deflate(&stream, zlib.FINISH)
			zlib.deflateEnd(&stream)
			if status != zlib.STREAM_END {
				delete(output)
				return Compressed_Data{}, .Compression_Failed
			}
			compressed = int(stream.total_out)
		}
	}
	if len(data) > 0 && compressed <= 0 {
		delete(output)
		return Compressed_Data{}, .Compression_Failed
	}
	result := make([dynamic]byte, 8+compressed)
	copy(result[:], output[:8+compressed])
	delete(output)
	output = result
	return Compressed_Data{Buffer = Byte_Buffer{Bytes = output}, Format = format}, .None
}

Create_Compressed_Data :: proc(data: []byte, format: Compression_Format) -> (Compressed_Data, Error) {
	capacity := len(data) + len(data)/255 + 64
	if format == .ZLIB {
		capacity = int(zlib.compressBound(zlib.uLong(len(data))))
	}
	if format == .LZ4 {
		capacity = int(lz4.compressBound(c.int(len(data))))
	}
	if format == .GZIP || format == .DEFLATE {
		capacity = len(data) + len(data)/1000 + 128
	}
	return compressed_with_size(format, data, capacity)
}

Decompress_Data :: proc(data: Compressed_Data) -> (Byte_Buffer, Error) {
	if len(data.Buffer.Bytes) < 8 {
		return Byte_Buffer{}, .Invalid_Data
	}
	output_size: u64
	for i := 0; i < 8; i += 1 {
		output_size |= u64(data.Buffer.Bytes[i]) << (u64(i) * 8)
	}
	if output_size == 0 {
		return Byte_Buffer{}, .None
	}
	if output_size > u64(max(int)) {
		return Byte_Buffer{}, .Compression_Failed
	}
	output := make([dynamic]byte, int(output_size))
	compressed := data.Buffer.Bytes[8:]
	decoded := 0
	switch data.Format {
	case .LZ4:
		decoded = int(lz4.decompress_safe(&compressed[0], &output[0], c.int(len(compressed)), c.int(len(output))))
	case .ZLIB:
		out_size := zlib.uLongf(len(output))
		status := zlib.uncompress(&output[0], &out_size, &compressed[0], zlib.uLong(len(compressed)))
		if status != zlib.OK {
			delete(output)
			return Byte_Buffer{}, .Compression_Failed
		}
		decoded = int(out_size)
	case .GZIP, .DEFLATE:
		window_bits := 15
		if data.Format == .GZIP {
			window_bits = 31
		} else {
			window_bits = -15
		}
		stream := zlib.z_stream{}
		if zlib.inflateInit2(&stream, c.int(window_bits)) != zlib.OK {
			delete(output)
			return Byte_Buffer{}, .Compression_Failed
		}
		stream.next_in = &compressed[0]
		stream.avail_in = zlib.uInt(len(compressed))
		stream.next_out = &output[0]
		stream.avail_out = zlib.uInt(len(output))
		status := zlib.inflate(&stream, zlib.FINISH)
		zlib.inflateEnd(&stream)
		if status != zlib.STREAM_END {
			delete(output)
			return Byte_Buffer{}, .Compression_Failed
		}
		decoded = int(stream.total_out)
	}
	if decoded != len(output) {
		delete(output)
		return Byte_Buffer{}, .Compression_Failed
	}
	return Byte_Buffer{Bytes = output}, .None
}
