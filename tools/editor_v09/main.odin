package editor_v09

// Thor2D v0.9 editor scaffolding: a pure-CLI project inspector (no window).
// Usage: thor2d-editor-v09 [project-dir-or-project.json]
// Defaults to examples/love_port_v08. Prints the project id, name, asset
// count, scene count and total entity count, validates via Validate_Project,
// and exits non-zero with a message on any invalid input.

import "core:fmt"
import "core:os"
import "core:strings"
import thor2d "thor2d:thor2d"

DEFAULT_PROJECT_DIR :: "examples/love_port_v08"

fail :: proc(message: string, detail: string) -> ! {
	if len(detail) > 0 {
		fmt.printf("thor2d-editor: %s: %s\n", message, detail)
	} else {
		fmt.printf("thor2d-editor: %s\n", message)
	}
	os.exit(1)
}

main :: proc() {
	target := DEFAULT_PROJECT_DIR
	if len(os.args) > 1 {
		target = os.args[1]
	}
	manifest := target
	manifest_owned := false
	if !strings.has_suffix(target, ".json") {
		manifest = strings.concatenate({target, "/project.json"})
		manifest_owned = true
	}
	// NOTE: the defer must live at function scope: a defer inside the if
	// block above would free `manifest` when the block exits.
	defer if manifest_owned do delete(manifest)

	data, read_err := os.read_entire_file(manifest, context.allocator)
	if read_err != nil {
		fail("cannot read project manifest", manifest)
	}
	defer delete(data)

	project := thor2d.Project{}
	if thor2d.Decode_JSON(data, &project) != .None {
		fail("manifest is not valid project JSON", manifest)
	}
	defer thor2d.Destroy_Project(&project)

	if thor2d.Validate_Project(&project) != .None {
		fail("manifest failed project validation", manifest)
	}

	entities := 0
	for scene in project.Scenes {
		entities += len(scene.Entities)
	}
	fmt.printf("project: %s\n", project.Project_Id)
	fmt.printf("name: %s\n", project.Name)
	fmt.printf("assets: %d\n", len(project.Assets))
	fmt.printf("scenes: %d\n", len(project.Scenes))
	fmt.printf("entities: %d\n", entities)
}
