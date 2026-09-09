package thor2d

import "core:os"
import "core:io"
import "core:strings"
import native_filesystem "thor2d:thor2d/internal/filesystem"

File_Exists :: proc(path: string) -> bool {
	return os.exists(path)
}

Read_File :: proc(path: string) -> ([]byte, os.Error) {
	return os.read_entire_file(path, context.allocator)
}

Write_File :: proc(path: string, data: []byte) -> os.Error {
	return os.write_entire_file(path, data)
}

Read_Text :: proc(path: string) -> (string, os.Error) {
	data, err := Read_File(path)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

Init_Filesystem :: proc(source_directory, save_directory: string) -> (Filesystem, Error) {
	if source_directory == "" || save_directory == "" {
		return Filesystem{}, .Path_Outside_Sandbox
	}
	if !os.exists(save_directory) {
		if os.make_directory_all(save_directory) != nil {
			return Filesystem{}, .File_Not_Found
		}
	}
	source, source_err := os.get_absolute_path(source_directory, context.allocator)
	if source_err != nil {
		return Filesystem{}, .Path_Outside_Sandbox
	}
	save, save_err := os.get_absolute_path(save_directory, context.allocator)
	if save_err != nil {
		delete(source)
		return Filesystem{}, .Path_Outside_Sandbox
	}
	identity, _ := strings.clone("thor2d")
	return Filesystem{Identity = identity, Source_Directory = source, Save_Directory = save}, .None
}

Destroy_Filesystem :: proc(filesystem: ^Filesystem) {
	if filesystem != nil {
		for archive in filesystem.archives {
			delete(archive.Path)
			delete(archive.Bytes)
			for entry in archive.Entries {
				delete(entry.Path)
			}
			delete(archive.Entries)
		}
		delete(filesystem.archives)
		delete(filesystem.Identity)
		delete(filesystem.Source_Directory)
		delete(filesystem.Save_Directory)
		filesystem^ = Filesystem{}
	}
}

Set_Identity :: proc(filesystem: ^Filesystem, identity: string) -> Error {
	if filesystem == nil || identity == "" {
		return .Invalid_Data
	}
	copy, clone_err := strings.clone(identity)
	if clone_err != nil {
		return .Invalid_Data
	}
	delete(filesystem.Identity)
	filesystem.Identity = copy
	return .None
}

Get_Identity :: proc(filesystem: ^Filesystem) -> string {
	if filesystem == nil {
		return ""
	}
	return filesystem.Identity
}

Get_Source_Directory :: proc(filesystem: ^Filesystem) -> string {
	if filesystem == nil {
		return ""
	}
	return filesystem.Source_Directory
}

Get_Save_Directory :: proc(filesystem: ^Filesystem) -> string {
	if filesystem == nil {
		return ""
	}
	return filesystem.Save_Directory
}

filesystem_resolve :: proc(root, relative: string) -> (string, Error) {
	if root == "" || relative == "" || os.is_absolute_path(relative) {
		return "", .Path_Outside_Sandbox
	}
	cleaned, clean_err := os.clean_path(relative, context.allocator)
	if clean_err != nil {
		return "", .Path_Outside_Sandbox
	}
	defer delete(cleaned)
	if cleaned == ".." || strings.has_prefix(cleaned, "../") || strings.has_prefix(cleaned, `..\`) {
		return "", .Path_Outside_Sandbox
	}
	joined, join_err := os.join_path([]string{root, cleaned}, context.allocator)
	if join_err != nil {
		return "", .Path_Outside_Sandbox
	}
	return joined, .None
}

Resolve_Source_Path :: proc(filesystem: ^Filesystem, relative: string) -> (string, Error) {
	if filesystem == nil {
		return "", .Invalid_Data
	}
	return filesystem_resolve(filesystem.Source_Directory, relative)
}

Resolve_Save_Path :: proc(filesystem: ^Filesystem, relative: string) -> (string, Error) {
	if filesystem == nil {
		return "", .Invalid_Data
	}
	return filesystem_resolve(filesystem.Save_Directory, relative)
}

Read_Source :: proc(filesystem: ^Filesystem, relative: string) -> (File_Data, Error) {
	path, err := Resolve_Source_Path(filesystem, relative)
	if err != .None {
		return File_Data{}, err
	}
	defer delete(path)
	if os.exists(path) {
		bytes, os_err := Read_File(path)
		if os_err != nil {
			return File_Data{}, .File_Not_Found
		}
		result, result_err := file_data_from_bytes(relative, bytes)
		delete(bytes)
		return result, result_err
	}
	if archive, entry, ok := find_archive_entry(filesystem, relative); ok {
		bytes, read_err := read_archive_entry(archive, entry)
		if read_err != .None {
			return File_Data{}, read_err
		}
		result, result_err := file_data_from_bytes(relative, bytes.Bytes[:])
		Destroy_Byte_Buffer(&bytes)
		return result, result_err
	}
	return File_Data{}, .File_Not_Found
}

// Read_Path follows Love2D-style precedence: save directory, source directory,
// then mounted package archives.
Read_Path :: proc(filesystem: ^Filesystem, relative: string) -> (File_Data, Error) {
	if filesystem == nil {
		return File_Data{}, .Invalid_Data
	}
	save_path, save_err := Resolve_Save_Path(filesystem, relative)
	if save_err != .None {
		return File_Data{}, save_err
	}
	defer delete(save_path)
	if os.exists(save_path) && !os.is_directory(save_path) {
		bytes, os_err := Read_File(save_path)
		if os_err == nil {
			result, result_err := file_data_from_bytes(relative, bytes)
			delete(bytes)
			return result, result_err
		}
	}
	return Read_Source(filesystem, relative)
}

Write_Save :: proc(filesystem: ^Filesystem, relative: string, data: []byte) -> Error {
	path, err := Resolve_Save_Path(filesystem, relative)
	if err != .None {
		return err
	}
	defer delete(path)
	if os.make_directory_all(os.dir(path)) != nil {
		return .File_Not_Found
	}
	if os.write_entire_file(path, data) != nil {
		return .File_Not_Found
	}
	return .None
}

Get_File_Info :: proc(filesystem: ^Filesystem, relative: string) -> (Thor2D_File_Info, Error) {
	if filesystem == nil {
		return Thor2D_File_Info{}, .Invalid_Data
	}
	save_path, save_err := Resolve_Save_Path(filesystem, relative)
	if save_err != .None {
		return Thor2D_File_Info{}, save_err
	}
	defer delete(save_path)
	path, err := Resolve_Source_Path(filesystem, relative)
	if err != .None {
		return Thor2D_File_Info{}, err
	}
	defer delete(path)
	if os.exists(save_path) && !os.is_directory(save_path) {
		file, open_err := os.open(save_path)
		if open_err != nil {
			return Thor2D_File_Info{}, .File_Not_Found
		}
		size, _ := os.file_size(file)
		os.close(file)
		return Thor2D_File_Info{Exists = true, Size = size}, .None
	}
	if !os.exists(path) {
		if _, entry, ok := find_archive_entry(filesystem, relative); ok {
			return Thor2D_File_Info{Exists = true, Size = i64(entry.Uncompressed_Size)}, .None
		}
		return Thor2D_File_Info{}, .File_Not_Found
	}
	info := Thor2D_File_Info{Exists = true, Directory = os.is_directory(path)}
	if !info.Directory {
		file, open_err := os.open(path)
		if open_err == nil {
			info.Size, _ = os.file_size(file)
			os.close(file)
		}
	}
	return info, .None
}

List_Directory :: proc(filesystem: ^Filesystem, relative: string) -> ([dynamic]Directory_Entry, Error) {
	if filesystem == nil {
		return nil, .Invalid_Data
	}
	path := ""
	if relative == "" {
		path, _ = strings.clone(filesystem.Source_Directory)
	} else {
		resolved, err := Resolve_Source_Path(filesystem, relative)
		if err != .None {
			return nil, err
		}
		path = resolved
	}
	defer delete(path)
	entries: [dynamic]Directory_Entry
	native_entries, native_ok := native_filesystem.List(path)
	if native_ok {
		for entry in native_entries {
			value, clone_err := strings.clone(entry.Path)
			if clone_err == nil {
				append(&entries, Directory_Entry{Path = value, Directory = entry.Directory})
			}
			delete(entry.Path)
		}
		delete(native_entries)
	}
	for archive in filesystem.archives {
		for archive_entry in archive.Entries {
			rest := archive_entry.Path
			if relative != "" {
				if archive_entry.Path == relative || !strings.has_prefix(archive_entry.Path, relative) || len(archive_entry.Path) <= len(relative) || archive_entry.Path[len(relative)] != '/' {
					continue
				}
				rest = archive_entry.Path[len(relative)+1:]
			}
			if rest == "" {
				continue
			}
			separator := strings.index_byte(rest, '/')
			child := rest
			is_directory := false
			if separator >= 0 {
				child = rest[:separator]
				is_directory = true
			}
			duplicate := false
			for current in entries {
				if current.Path == child {
					duplicate = true
					break
				}
			}
			if !duplicate {
				value, clone_err := strings.clone(child)
				if clone_err == nil {
					append(&entries, Directory_Entry{Path = value, Directory = is_directory})
				}
			}
		}
	}
	if len(entries) == 0 && !native_ok {
		return nil, .File_Not_Found
	}
	return entries, .None
}

mount_archive_file :: proc(filesystem: ^Filesystem, path: string) -> Error {
	if filesystem == nil || path == "" {
		return .Invalid_Data
	}
	bytes, read_err := Read_File(path)
	if read_err != nil {
		return .File_Not_Found
	}
	archive, parse_err := parse_zip_archive(path, bytes)
	delete(bytes)
	if parse_err != .None {
		return parse_err
	}
	append(&filesystem.archives, archive)
	return .None
}

// Mount_Archive mounts a package relative to the source directory.
Mount_Archive :: proc(filesystem: ^Filesystem, archive_path: string) -> Error {
	if filesystem == nil {
		return .Invalid_Data
	}
	path, path_err := Resolve_Source_Path(filesystem, archive_path)
	if path_err != .None {
		return path_err
	}
	defer delete(path)
	return mount_archive_file(filesystem, path)
}

// Mount_Archive_File is used by packaged runners that keep the archive
// outside the project's source directory. It still stores only the archive
// bytes and never extracts its entries.
Mount_Archive_File :: proc(filesystem: ^Filesystem, archive_path: string) -> Error {
	if filesystem == nil || archive_path == "" || !os.is_absolute_path(archive_path) {
		return .Path_Outside_Sandbox
	}
	return mount_archive_file(filesystem, archive_path)
}

Unmount_Archive :: proc(filesystem: ^Filesystem, archive_path: string) -> Error {
	if filesystem == nil {
		return .Invalid_Data
	}
	path, path_err := Resolve_Source_Path(filesystem, archive_path)
	if path_err != .None {
		return path_err
	}
	defer delete(path)
	for i := 0; i < len(filesystem.archives); i += 1 {
		if filesystem.archives[i].Path == path {
			archive := filesystem.archives[i]
			delete(archive.Path)
			delete(archive.Bytes)
			for entry in archive.Entries {
				delete(entry.Path)
			}
			delete(archive.Entries)
			unordered_remove(&filesystem.archives, i)
			return .None
		}
	}
	return .File_Not_Found
}

// File is a streaming handle for physical files in the sandbox. Mounted ZIP
// entries remain read-through File_Data values for now; they are intentionally
// not exposed as a seekable OS handle because compressed entries have no
// stable native descriptor.
File :: struct {
	native: ^os.File,
	writable: bool,
}

Open_File :: proc(filesystem: ^Filesystem, relative: string, mode := File_Open_Mode.Read) -> (^File, Error) {
	if filesystem == nil || relative == "" {
		return nil, .Invalid_Data
	}
	flags: os.File_Flags
	root_path: string
	writable := false
	switch mode {
	case .Read:
		writable = false
		save_path, save_err := Resolve_Save_Path(filesystem, relative)
		if save_err != .None {
			return nil, save_err
		}
		if os.exists(save_path) && !os.is_directory(save_path) {
			root_path = save_path
		} else {
			delete(save_path)
			root_path, save_err = Resolve_Source_Path(filesystem, relative)
			if save_err != .None {
				return nil, save_err
			}
		}
		flags = os.File_Flags{.Read}
	case .Write:
		writable = true
		root_path, _ = Resolve_Save_Path(filesystem, relative)
		flags = os.File_Flags{.Write, .Create, .Trunc}
	case .Read_Write:
		writable = true
		root_path, _ = Resolve_Save_Path(filesystem, relative)
		flags = os.File_Flags{.Read, .Write, .Create}
	}
	native, open_err := os.open(root_path, flags, os.Permissions_Default_File)
	delete(root_path)
	if open_err != nil {
		return nil, .File_Not_Found
	}
	file := new(File)
	file.native = native
	file.writable = writable
	return file, .None
}

Read_File_Handle :: proc(file: ^File, destination: []byte) -> (int, Error) {
	if file == nil || file.native == nil {
		return 0, .Invalid_Handle
	}
	count, err := os.read(file.native, destination)
	if err != nil {
		return count, .File_Not_Found
	}
	return count, .None
}

Write_File_Handle :: proc(file: ^File, data: []byte) -> (int, Error) {
	if file == nil || file.native == nil || !file.writable {
		return 0, .Invalid_Handle
	}
	count, err := os.write(file.native, data)
	if err != nil {
		return count, .File_Not_Found
	}
	return count, .None
}

Seek_File :: proc(file: ^File, offset: i64, origin := io.Seek_From.Start) -> (i64, Error) {
	if file == nil || file.native == nil {
		return 0, .Invalid_Handle
	}
	position, err := os.seek(file.native, offset, origin)
	if err != nil {
		return position, .File_Not_Found
	}
	return position, .None
}

Tell_File :: proc(file: ^File) -> (i64, Error) {
	return Seek_File(file, 0, .Current)
}

Close_File :: proc(file: ^File) -> Error {
	if file == nil || file.native == nil {
		return .Invalid_Handle
	}
	if err := os.close(file.native); err != nil {
		return .File_Not_Found
	}
	file.native = nil
	return .None
}

file_data_from_bytes :: proc(relative: string, bytes: []byte) -> (File_Data, Error) {
	stored_path, path_err := strings.clone(relative)
	if path_err != nil {
		return File_Data{}, .Invalid_Data
	}
	stored_bytes := make([dynamic]byte, len(bytes))
	copy(stored_bytes[:], bytes)
	return File_Data{Bytes = stored_bytes, Path = stored_path}, .None
}

read_u16_le :: proc(bytes: []byte, offset: int) -> (u16, bool) {
	if offset < 0 || offset+2 > len(bytes) {
		return 0, false
	}
	return u16(bytes[offset]) | u16(bytes[offset+1]) << 8, true
}

read_u32_le :: proc(bytes: []byte, offset: int) -> (u32, bool) {
	if offset < 0 || offset+4 > len(bytes) {
		return 0, false
	}
	return u32(bytes[offset]) | u32(bytes[offset+1]) << 8 | u32(bytes[offset+2]) << 16 | u32(bytes[offset+3]) << 24, true
}

normalize_archive_entry_path :: proc(path: string) -> (string, bool) {
	if path == "" || path[0] == '/' || path[0] == '\\' {
		return "", false
	}
	buffer := make([dynamic]byte, len(path))
	copy(buffer[:], transmute([]byte)path)
	for i := 0; i < len(buffer); i += 1 {
		if buffer[i] == '\\' {
			buffer[i] = '/'
		}
	}
	value, clone_err := strings.clone(string(buffer[:]))
	delete(buffer)
	if clone_err != nil {
		return "", false
	}
	segment_start := 0
	for i := 0; i <= len(value); i += 1 {
		if i == len(value) || value[i] == '/' {
			if value[segment_start:i] == ".." {
				delete(value)
				return "", false
			}
			segment_start = i + 1
		}
	}
	return value, true
}

parse_zip_archive :: proc(path: string, bytes: []byte) -> (Filesystem_Archive, Error) {
	start := len(bytes) - 22 - 65535
	if start < 0 {
		start = 0
	}
	eocd := -1
	for i := len(bytes) - 22; i >= start; i -= 1 {
		magic, ok := read_u32_le(bytes, i)
		if ok && magic == 0x06054b50 {
			eocd = i
			break
		}
	}
	if eocd < 0 {
		return Filesystem_Archive{}, .Invalid_Data
	}
	count, count_ok := read_u16_le(bytes, eocd+10)
	central_size, size_ok := read_u32_le(bytes, eocd+12)
	central_offset, offset_ok := read_u32_le(bytes, eocd+16)
	if !count_ok || !size_ok || !offset_ok || u64(central_offset)+u64(central_size) > u64(len(bytes)) {
		return Filesystem_Archive{}, .Invalid_Data
	}
	archive_path, path_err := strings.clone(path)
	if path_err != nil {
		return Filesystem_Archive{}, .Invalid_Data
	}
	archive_bytes := make([dynamic]byte, len(bytes))
	copy(archive_bytes[:], bytes)
	archive := Filesystem_Archive{Path = archive_path, Bytes = archive_bytes}
	position := int(central_offset)
	for i := 0; i < int(count); i += 1 {
		magic, ok := read_u32_le(bytes, position)
		if !ok || magic != 0x02014b50 {
			Destroy_Zip_Archive(&archive)
			return Filesystem_Archive{}, .Invalid_Data
		}
		method, method_ok := read_u16_le(bytes, position+10)
		compressed_size, compressed_ok := read_u32_le(bytes, position+20)
		uncompressed_size, uncompressed_ok := read_u32_le(bytes, position+24)
		name_size, name_ok := read_u16_le(bytes, position+28)
		extra_size, extra_ok := read_u16_le(bytes, position+30)
		comment_size, comment_ok := read_u16_le(bytes, position+32)
		local_offset, local_ok := read_u32_le(bytes, position+42)
		if !method_ok || !compressed_ok || !uncompressed_ok || !name_ok || !extra_ok || !comment_ok || !local_ok {
			Destroy_Zip_Archive(&archive)
			return Filesystem_Archive{}, .Invalid_Data
		}
		name_start := position + 46
		name_end := name_start + int(name_size)
		if name_end > len(bytes) {
			Destroy_Zip_Archive(&archive)
			return Filesystem_Archive{}, .Invalid_Data
		}
		name, name_valid := normalize_archive_entry_path(string(bytes[name_start:name_end]))
		if !name_valid {
			Destroy_Zip_Archive(&archive)
			return Filesystem_Archive{}, .Path_Outside_Sandbox
		}
		position = name_end + int(extra_size) + int(comment_size)
		if position > len(bytes) {
			Destroy_Zip_Archive(&archive)
			return Filesystem_Archive{}, .Invalid_Data
		}
		if strings.has_suffix(name, "/") {
			delete(name)
			continue
		}
		local_magic, local_magic_ok := read_u32_le(bytes, int(local_offset))
		local_name_size, local_name_ok := read_u16_le(bytes, int(local_offset)+26)
		local_extra_size, local_extra_ok := read_u16_le(bytes, int(local_offset)+28)
		data_offset := int(local_offset) + 30 + int(local_name_size) + int(local_extra_size)
		if !local_magic_ok || !local_name_ok || !local_extra_ok || local_magic != 0x04034b50 || data_offset < 0 || u64(data_offset)+u64(compressed_size) > u64(len(bytes)) {
			Destroy_Zip_Archive(&archive)
			return Filesystem_Archive{}, .Invalid_Data
		}
		stored_name, clone_err := strings.clone(name)
		if clone_err != nil {
			Destroy_Zip_Archive(&archive)
			return Filesystem_Archive{}, .Invalid_Data
		}
		append(&archive.Entries, Filesystem_Archive_Entry{
			Path = stored_name,
			Method = method,
			Data_Offset = data_offset,
			Compressed_Size = int(compressed_size),
			Uncompressed_Size = int(uncompressed_size),
		})
		delete(name)
	}
	return archive, .None
}

Destroy_Zip_Archive :: proc(archive: ^Filesystem_Archive) {
	if archive == nil {
		return
	}
	delete(archive.Path)
	delete(archive.Bytes)
	for entry in archive.Entries {
		delete(entry.Path)
	}
	delete(archive.Entries)
}

find_archive_entry :: proc(filesystem: ^Filesystem, relative: string) -> (^Filesystem_Archive, ^Filesystem_Archive_Entry, bool) {
	if filesystem == nil {
		return nil, nil, false
	}
	normalized, ok := normalize_archive_entry_path(relative)
	if !ok {
		return nil, nil, false
	}
	for archive_index := len(filesystem.archives)-1; archive_index >= 0; archive_index -= 1 {
		archive := &filesystem.archives[archive_index]
		for entry_index := 0; entry_index < len(archive.Entries); entry_index += 1 {
			entry := &archive.Entries[entry_index]
			if entry.Path == normalized {
				delete(normalized)
				return archive, entry, true
			}
		}
	}
	delete(normalized)
	return nil, nil, false
}

read_archive_entry :: proc(archive: ^Filesystem_Archive, entry: ^Filesystem_Archive_Entry) -> (Byte_Buffer, Error) {
	if archive == nil || entry == nil || entry.Data_Offset < 0 || entry.Compressed_Size < 0 || entry.Data_Offset+entry.Compressed_Size > len(archive.Bytes) {
		return Byte_Buffer{}, .Invalid_Handle
	}
	compressed := archive.Bytes[entry.Data_Offset:entry.Data_Offset+entry.Compressed_Size]
	if entry.Method == 0 {
		result := make([dynamic]byte, len(compressed))
		copy(result[:], compressed)
		return Byte_Buffer{Bytes = result}, .None
	}
	if entry.Method != 8 {
		return Byte_Buffer{}, .Unsupported
	}
	wrapped := make([dynamic]byte, 8+len(compressed))
	size := u64(entry.Uncompressed_Size)
	for i := 0; i < 8; i += 1 {
		wrapped[i] = byte(size >> (u64(i) * 8))
	}
	copy(wrapped[8:], compressed)
	decoded, err := Decompress_Data(Compressed_Data{Buffer = Byte_Buffer{Bytes = wrapped}, Format = .DEFLATE})
	delete(wrapped)
	return decoded, err
}
