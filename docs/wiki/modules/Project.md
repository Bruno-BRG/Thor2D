# Project manifests

Source: `src/thor2d/project.odin`. A `Project` contains schema version, name,
project ID, asset records and scene records. These operations work without a
window; file operations take `^Filesystem`, not `^Context`.

## Creation and ownership

`New_Project(name, project_id)` returns schema version 1 and owned copies of
the two strings. It does not validate them. Call `Destroy_Project(&project)`
to release strings, asset records, scenes and entity component data. Destruction
accepts nil and resets the project to its zero value.

## Assets

`Asset_Id_From_Path(path)` hashes the path bytes with 64-bit FNV-1a. It maps a
zero hash to 1. It does not normalize paths, read the file or check collisions.

`Add_Project_Asset(&project, path, kind)` returns `(Asset_Id, Error)`:

- Nil project, empty path or a leading slash/backslash: `.Path_Outside_Sandbox`.
- Existing ID or identical path: returns the existing ID without changing it.
- Otherwise: copies path/kind into the asset list and returns `.None`.

This is metadata registration, not file loading. The current path check is not
full canonicalization: it does not reject every possible traversal spelling.
Filesystem access has its own sandbox checks.

## Validation and persistence

`Validate_Project(&project)` returns `.Project_Invalid` for nil, nonpositive
schema version, empty name/ID, zero asset IDs, invalid asset paths or duplicate
asset IDs. It does not inspect asset file contents or validate scene components.

`Save_Project(filesystem, relative_path, &project)` validates, encodes JSON and
writes through `Write_Save`. Validation failure becomes `.Project_Invalid`;
encoding and file errors propagate to the caller.

`Load_Project(filesystem, relative_path)` returns `(Project, Error)`. It reads
through `Read_Source`, decodes JSON and validates the result. Read errors
propagate; invalid JSON or invalid metadata returns `.Project_Invalid` and an
empty project. The caller owns a successful result.

## Example

```odin
project := thor2d.New_Project("Example", "org.example.game")
defer thor2d.Destroy_Project(&project)
id, err := thor2d.Add_Project_Asset(&project, "assets/player.png", "texture")
assert(err == .None && id != 0)
assert(thor2d.Validate_Project(&project) == .None)
```

Asset entries are objects with fields such as `id`, `path` and `kind`, not
strings. Packaging the directory into a `.thor` archive is a separate build
operation; `Save_Project` writes JSON only.
