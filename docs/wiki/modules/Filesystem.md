# thor2d.Filesystem

LOVE equivalent: `love.filesystem`. Sources: `filesystem.odin`, `filesystem_extra.odin`.

## Description

Sandboxed source/save/archive layers. Lookup order: save dir → project dir → mounted `.thor` archive. Source and archives are read-only; only the save dir is writable.

## Types

`Filesystem`, `File_Open_Mode`, `File`, `Thor2D_File_Info`, `Directory_Entry`, `Filesystem_Archive`.

## Functions

- `Init_Filesystem(src, save)` / `Destroy_Filesystem` / `Filesystem_Access(ctx)` — setup.
- `Set_Identity(fs, id)` / `Get_Identity(fs)` — LOVE `setIdentity/getIdentity`.
- `Get_Source_Directory` / `Get_Save_Directory` — LOVE `getSource/getSaveDirectory`.
- `Read_Source/Read_Path/Write_Save` — LOVE `read/write` with save precedence.
- `Get_File_Info(fs, p)` + `Is_File/Is_Directory/File_Size` — LOVE `getInfo` (+ `isFile/isDirectory/getSize`).
- `List_Directory(fs, p)` — LOVE `getDirectoryItems`.
- `Create_Directory(fs, p)` — LOVE `createDirectory`.
- `Remove_Path(fs, p)` — LOVE `remove`.
- `Append_Save(fs, p, data)` — LOVE `append`.
- `Mount_Archive/Mount_Archive_File/Unmount_Archive` — LOVE `mount/unmount` (stored/deflate ZIP only).
- `Open_File/Read_File_Handle/Write_File_Handle/Seek_File/Tell_File/Close_File` — LOVE `newFile` + `File:*` (physical files only, not ZIP entries).
- `File_Is_Open/File_Is_EOF/File_Size_Of` — LOVE `File:isOpen/isEOF/getSize` on an open handle (closed handles: `Is_Open` false, `Is_EOF` true, `Size_Of` → `.Invalid_Handle`).
- `File_Name/File_Mode` — LOVE `File:getFilename/getMode` (stored at `Open_File`, valid after `Close_File`; the owning `Filesystem` releases file records during `Destroy_Filesystem`).
- `File_Read_Line(file)` — one `\n`-terminated line (`\r` stripped), owned string; EOF-before-bytes → `.File_Not_Found` (LOVE line-iteration single step; `File_Lines` still covers whole-file reads).
- `File_Flush(file)` — LOVE `File:flush`; honest no-op `.None` (writes are unbuffered `os.write`, nothing to flush).
- `File_Set_Buffer_Mode(file, mode)` / `File_Buffer_Mode_Of(file)` — LOVE `File:setBuffer/getBuffer` with `File_Buffer_Mode{None, Line, Full}`; only `.None` is honored, `.Line`/`.Full` → `.Unsupported` (no buffering to configure).
- `New_File_Data(path, data)` / `File_Data_Name/File_Data_Extension` — LOVE `newFileData` data half + name/extension helpers (pure strings, no I/O).
- `Mount_Archive_Memory(fs, name, data)` — LOVE `mount` from bytes (same stored/deflate ZIP reader as `Mount_Archive`; memory archives live until `Destroy_Filesystem`, not `Unmount_Archive`).
- `Are_Symlinks_Enabled/Set_Symlinks_Enabled` — symlink intent flag (default true); advisory only, the `..` sandbox stays enforced either way.
- `Get_Working_Directory/Get_User_Directory/Get_Appdata_Directory` — LOVE directory queries.
- `Get_Source_Base_Directory/Get_Real_Directory` — LOVE `getSourceBaseDirectory/getRealDirectory`.
- `Is_Fused(fs)` — LOVE `isFused` (true inside `.thor`).
- `File_Lines(fs, p)` — LOVE `lines`.
- Raw helpers: `File_Exists/Read_File/Write_File/Read_Text` (unsandboxed; prefer the `fs` variants in games).

## Examples

```odin
fs := thor2d.Filesystem_Access(ctx)
ok := thor2d.Create_Directory(fs, "saves/slot1")
err := thor2d.Append_Save(fs, "log.txt", transmute([]u8)string("hi\n"))
```

## See Also

[Data](Data.md).
