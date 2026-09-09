package thor2d_filesystem

import "core:strings"
import rl "vendor:raylib"

Entry :: struct {
	Path: string,
	Directory: bool,
}

List :: proc(path: string) -> ([dynamic]Entry, bool) {
	c_path, err := strings.clone_to_cstring(path, context.temp_allocator)
	if err != nil {
		return nil, false
	}
	files := rl.LoadDirectoryFiles(c_path)
	result: [dynamic]Entry
	for i := 0; i < int(files.count); i += 1 {
		value, clone_err := strings.clone(string(files.paths[i]))
		if clone_err == nil {
			append(&result, Entry{Path = value, Directory = !rl.IsPathFile(files.paths[i])})
		}
	}
	rl.UnloadDirectoryFiles(files)
	return result, true
}
