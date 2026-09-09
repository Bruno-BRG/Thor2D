package thor2d

import "core:strings"

Project_Schema_Version :: 1

New_Project :: proc(name, project_id: string) -> Project {
	project := Project{Schema_Version = Project_Schema_Version}
	project.Name, _ = strings.clone(name)
	project.Project_Id, _ = strings.clone(project_id)
	return project
}

Destroy_Project :: proc(project: ^Project) {
	if project == nil {
		return
	}
	delete(project.Project_Id)
	delete(project.Name)
	for asset in project.Assets {
		delete(asset.Path)
		delete(asset.Kind)
		delete(asset.Hash)
	}
	delete(project.Assets)
	for scene in project.Scenes {
		delete(scene.Id)
		delete(scene.Name)
		for entity in scene.Entities {
			delete(entity.Name)
			for _, value in entity.Components {
				delete(value)
			}
			delete(entity.Components)
		}
		delete(scene.Entities)
	}
	delete(project.Scenes)
	project^ = Project{}
}

Asset_Id_From_Path :: proc(path: string) -> Asset_Id {
	// FNV-1a is deliberately small and stable across platforms. The manifest
	// persists this value, so a path rename can keep the old id when requested.
	value: u64 = 14695981039346656037
	for c in path {
		value = value ~ u64(c)
		value *= 1099511628211
	}
	if value == 0 {
		value = 1
	}
	return Asset_Id(value)
}

Add_Project_Asset :: proc(project: ^Project, path, kind: string) -> (Asset_Id, Error) {
	if project == nil || path == "" || strings.has_prefix(path, "/") || strings.has_prefix(path, `\`) {
		return Asset_Id(0), .Path_Outside_Sandbox
	}
	id := Asset_Id_From_Path(path)
	for asset in project.Assets {
		if asset.Id == u64(id) || asset.Path == path {
			return Asset_Id(asset.Id), .None
		}
	}
	asset := Project_Asset{Id = u64(id)}
	asset.Path, _ = strings.clone(path)
	asset.Kind, _ = strings.clone(kind)
	append(&project.Assets, asset)
	return id, .None
}

Validate_Project :: proc(project: ^Project) -> Error {
	if project == nil || project.Schema_Version <= 0 || project.Project_Id == "" || project.Name == "" {
		return .Project_Invalid
	}
	asset_ids := make(map[Asset_Id]bool)
	defer delete(asset_ids)
	for asset in project.Assets {
		if asset.Id == 0 || asset.Path == "" || strings.has_prefix(asset.Path, "/") || strings.has_prefix(asset.Path, `\`) {
			return .Project_Invalid
		}
		if _, exists := asset_ids[Asset_Id(asset.Id)]; exists {
			return .Project_Invalid
		}
		asset_ids[Asset_Id(asset.Id)] = true
	}
	return .None
}

Save_Project :: proc(filesystem: ^Filesystem, relative_path: string, project: ^Project) -> Error {
	if Validate_Project(project) != .None {
		return .Project_Invalid
	}
	data, err := Encode_JSON(project)
	if err != .None {
		return err
	}
	defer Destroy_Byte_Buffer(&data)
	return Write_Save(filesystem, relative_path, data.Bytes[:])
}

Load_Project :: proc(filesystem: ^Filesystem, relative_path: string) -> (Project, Error) {
	file, err := Read_Source(filesystem, relative_path)
	if err != .None {
		return Project{}, err
	}
	defer Destroy_File_Data(&file)
	project: Project
	if Decode_JSON(file.Bytes[:], &project) != .None {
		Destroy_Project(&project)
		return Project{}, .Project_Invalid
	}
	if Validate_Project(&project) != .None {
		Destroy_Project(&project)
		return Project{}, .Project_Invalid
	}
	return project, .None
}
