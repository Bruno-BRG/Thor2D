package thor2d

import "core:os"
import "core:strings"

// v0.8 LOVE-parity filesystem gaps. All mutating procs stay inside the
// sandboxed save directory; source/archive mounts remain read-only.

Create_Directory :: proc(filesystem: ^Filesystem, relative: string) -> Error {
	if filesystem == nil {
		return .Invalid_Data
	}
	path, err := Resolve_Save_Path(filesystem, relative)
	if err != .None {
		return err
	}
	defer delete(path)
	if !os.exists(path) {
		if os.make_directory_all(path) != nil {
			return .File_Not_Found
		}
	} else if !os.is_directory(path) {
		return .Invalid_Data
	}
	return .None
}

Remove_Path :: proc(filesystem: ^Filesystem, relative: string) -> Error {
	if filesystem == nil {
		return .Invalid_Data
	}
	path, err := Resolve_Save_Path(filesystem, relative)
	if err != .None {
		return err
	}
	defer delete(path)
	if !os.exists(path) {
		return .File_Not_Found
	}
	if os.is_directory(path) {
		if os.remove(path) != nil {
			return .File_Not_Found
		}
		return .None
	}
	if os.remove(path) != nil {
		return .File_Not_Found
	}
	return .None
}

Append_Save :: proc(filesystem: ^Filesystem, relative: string, data: []byte) -> Error {
	if filesystem == nil {
		return .Invalid_Data
	}
	path, err := Resolve_Save_Path(filesystem, relative)
	if err != .None {
		return err
	}
	defer delete(path)
	parent := os.dir(path)
	if !os.exists(parent) {
		if os.make_directory_all(parent) != nil {
			return .File_Not_Found
		}
	}
	handle, open_err := os.open(path, os.O_APPEND | os.O_WRONLY | os.O_CREATE)
	if open_err != nil {
		return .File_Not_Found
	}
	defer os.close(handle)
	if _, write_err := os.write(handle, data); write_err != nil {
		return .File_Not_Found
	}
	return .None
}

File_Size :: proc(filesystem: ^Filesystem, relative: string) -> (int, Error) {
	info, err := Get_File_Info(filesystem, relative)
	if err != .None {
		return 0, err
	}
	if info.Directory {
		return 0, .Invalid_Data
	}
	return int(info.Size), .None
}

Is_Directory :: proc(filesystem: ^Filesystem, relative: string) -> bool {
	if filesystem == nil {
		return false
	}
	info, err := Get_File_Info(filesystem, relative)
	return err == .None && info.Exists && info.Directory
}

Is_File :: proc(filesystem: ^Filesystem, relative: string) -> bool {
	if filesystem == nil {
		return false
	}
	info, err := Get_File_Info(filesystem, relative)
	return err == .None && info.Exists && !info.Directory
}

Get_Working_Directory :: proc() -> string {
	dir, err := os.get_working_directory(context.allocator)
	if err != nil {
		return ""
	}
	return dir
}

Get_User_Directory :: proc() -> string {
	if home, found := os.lookup_env("HOME", context.allocator); found {
		return home
	}
	return ""
}

Get_Appdata_Directory :: proc() -> string {
	if xdg, found := os.lookup_env("XDG_DATA_HOME", context.allocator); found {
		return xdg
	}
	home := Get_User_Directory()
	if home == "" {
		return ""
	}
	joined, err := os.join_path([]string{home, ".local/share"}, context.allocator)
	if err != nil {
		return ""
	}
	return joined
}

Get_Source_Base_Directory :: proc(filesystem: ^Filesystem) -> string {
	if filesystem == nil {
		return ""
	}
	value, _ := strings.clone(os.dir(filesystem.Source_Directory))
	return value
}

Get_Real_Directory :: proc(filesystem: ^Filesystem, relative: string) -> string {
	// Returns which layer provides the file: save dir, source dir, or archive.
	if filesystem == nil {
		return ""
	}
	save_path, save_err := Resolve_Save_Path(filesystem, relative)
	if save_err == .None {
		defer delete(save_path)
		if os.exists(save_path) {
			value, _ := strings.clone(filesystem.Save_Directory)
			return value
		}
	}
	source_path, source_err := Resolve_Source_Path(filesystem, relative)
	if source_err == .None {
		defer delete(source_path)
		if os.exists(source_path) {
			value, _ := strings.clone(filesystem.Source_Directory)
			return value
		}
	}
	if _, _, ok := find_archive_entry(filesystem, relative); ok {
		value, _ := strings.clone("(archive)")
		return value
	}
	return ""
}

Is_Fused :: proc(filesystem: ^Filesystem) -> bool {
	return filesystem != nil && len(filesystem.archives) > 0
}

File_Lines :: proc(filesystem: ^Filesystem, relative: string) -> ([]string, Error) {
	data, err := Read_Path(filesystem, relative)
	if err != .None {
		return nil, err
	}
	defer Destroy_File_Data(&data)
	text := string(data.Bytes[:])
	lines := strings.split_lines(text, context.allocator)
	return lines, .None
}

// v0.10 LOVE File:* completion (mirrors love.filesystem.newFile + File
// methods). All procs are headless-safe (pure OS I/O, no backend).

// File_Is_Open mirrors love File:isOpen. Nil or closed handles report false.
File_Is_Open :: proc(file: ^File) -> bool {
	return file != nil && file.native != nil
}

// File_Is_EOF mirrors love File:isEOF. Closed handles and I/O errors report
// true (conservative: there is nothing more to read).
File_Is_EOF :: proc(file: ^File) -> bool {
	if file == nil || file.native == nil {
		return true
	}
	size, size_err := os.file_size(file.native)
	if size_err != nil {
		return true
	}
	position, tell_err := Tell_File(file)
	if tell_err != .None {
		return true
	}
	return position >= size
}

// File_Size_Of mirrors love File:getSize on an open handle.
File_Size_Of :: proc(file: ^File) -> (i64, Error) {
	if file == nil || file.native == nil {
		return 0, .Invalid_Handle
	}
	size, err := os.file_size(file.native)
	if err != nil {
		return 0, .File_Not_Found
	}
	return size, .None
}

// File_Name mirrors love File:getFilename: the relative path passed to
// Open_File. The string is owned by the handle; do not delete it. Empty when
// the handle was created without a stored path.
File_Name :: proc(file: ^File) -> string {
	if file == nil {
		return ""
	}
	return file.Path
}

// File_Mode mirrors love File:getMode: the mode passed to Open_File.
File_Mode :: proc(file: ^File) -> File_Open_Mode {
	if file == nil {
		return .Read
	}
	return file.Mode
}

// File_Read_Line reads one \n-terminated line (mirrors love File:read line
// iteration for a single line). The trailing \n — and a preceding \r — are
// stripped. The returned string is owned by the caller (delete it). EOF
// before any byte maps to .File_Not_Found; a closed handle maps to
// .Invalid_Handle.
File_Read_Line :: proc(file: ^File) -> (string, Error) {
	if file == nil || file.native == nil {
		return "", .Invalid_Handle
	}
	line := make([dynamic]byte, 0, 64)
	defer delete(line)
	byte_buffer := make([]byte, 1)
	defer delete(byte_buffer)
	for {
		count, read_err := os.read(file.native, byte_buffer)
		if read_err != nil || count <= 0 {
			break
		}
		if byte_buffer[0] == '\n' {
			break
		}
		append(&line, byte_buffer[0])
	}
	if len(line) == 0 {
		// Distinguish real EOF from a blank line: blank lines carry the \n
		// (consumed above) only when bytes were available; with no bytes at
		// all the handle is at EOF.
		if File_Is_EOF(file) {
			return "", .File_Not_Found
		}
	}
	for len(line) > 0 && line[len(line)-1] == '\r' {
		pop(&line)
	}
	result, clone_err := strings.clone(string(line[:]))
	if clone_err != nil {
		return "", .Invalid_Data
	}
	return result, .None
}

// File_Flush mirrors love File:flush. Writes via Write_File_Handle go
// straight to the OS (os.write is unbuffered), so there is nothing to flush:
// this is an honest no-op returning .None on open handles, .Invalid_Handle
// otherwise.
File_Flush :: proc(file: ^File) -> Error {
	if file == nil || file.native == nil {
		return .Invalid_Handle
	}
	return .None
}

// File_Set_Buffer_Mode mirrors love File:setBuffer. The backend is
// unbuffered, so .None is accepted (stored) while .Line/.Full return
// .Unsupported instead of pretending to buffer.
File_Set_Buffer_Mode :: proc(file: ^File, mode: File_Buffer_Mode) -> Error {
	if file == nil {
		return .Invalid_Handle
	}
	if mode != .None {
		return .Unsupported
	}
	file.Buffer_Mode = mode
	return .None
}

// File_Buffer_Mode_Of mirrors love File:getBuffer. Always .None in practice
// (see File_Set_Buffer_Mode); nil handles report .None.
File_Buffer_Mode_Of :: proc(file: ^File) -> File_Buffer_Mode {
	if file == nil {
		return .None
	}
	return file.Buffer_Mode
}

// New_File_Data builds an owned File_Data from caller bytes (public wrapper
// over the read-path constructor; mirrors love.filesystem.newFileData data
// half). Path is stored verbatim (no sandbox check: no I/O happens).
New_File_Data :: proc(path: string, data: []byte) -> (File_Data, Error) {
	return file_data_from_bytes(path, data)
}

// File_Data_Name returns the File_Data path verbatim (mirrors
// love FileData:getName-ish identity; the stored relative path).
File_Data_Name :: proc(data: ^File_Data) -> string {
	if data == nil {
		return ""
	}
	return data.Path
}

// File_Data_Extension returns the lowercase extension after the last dot of
// the last path segment ("" when none). Pure string helper, no I/O.
File_Data_Extension :: proc(data: ^File_Data) -> string {
	if data == nil || data.Path == "" {
		return ""
	}
	path := data.Path
	segment_start := 0
	for i := len(path)-1; i >= 0; i -= 1 {
		if path[i] == '/' || path[i] == '\\' {
			segment_start = i+1
			break
		}
	}
	dot := -1
	for i := len(path)-1; i >= segment_start; i -= 1 {
		if path[i] == '.' {
			dot = i
			break
		}
	}
	if dot < 0 || dot+1 >= len(path) {
		return ""
	}
	return path[dot+1:]
}

// Mount_Archive_Memory mounts a ZIP archive from memory (mirrors mounting a
// fused/love archive without touching disk). The parser is the same stored /
// deflate ZIP reader as Mount_Archive, so only those methods load; anything
// else surfaces as .Unsupported at read time. name is stored as the archive
// identity (used in listings, not resolvable by Unmount_Archive, which takes
// source-relative paths — memory archives live until Destroy_Filesystem).
Mount_Archive_Memory :: proc(filesystem: ^Filesystem, name: string, data: []byte) -> Error {
	if filesystem == nil || name == "" || len(data) == 0 {
		return .Invalid_Data
	}
	archive, parse_err := parse_zip_archive(name, data)
	if parse_err != .None {
		return parse_err
	}
	append(&filesystem.archives, archive)
	return .None
}

// Are_Symlinks_Enabled reports the symlink intent flag (default true). The
// backend follows OS symlinks on reads; the sandbox (.. escape rejection)
// stays enforced regardless of this flag.
Are_Symlinks_Enabled :: proc(filesystem: ^Filesystem) -> bool {
	if filesystem == nil {
		return false
	}
	return filesystem.Symlinks_Enabled
}

// Set_Symlinks_Enabled stores the symlink intent flag. Advisory only (see
// Are_Symlinks_Enabled); always honored as a stored value.
Set_Symlinks_Enabled :: proc(filesystem: ^Filesystem, enabled: bool) -> Error {
	if filesystem == nil {
		return .Invalid_Data
	}
	filesystem.Symlinks_Enabled = enabled
	return .None
}
