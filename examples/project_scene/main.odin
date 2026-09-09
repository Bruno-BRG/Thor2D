package project_scene

import "core:fmt"
import thor2d "thor2d:thor2d"

main :: proc() {
	filesystem, err := thor2d.Init_Filesystem(".", ".thor2d-save")
	if err != .None {
		fmt.println(thor2d.Error_String(err))
		return
	}
	defer thor2d.Destroy_Filesystem(&filesystem)
	project := thor2d.New_Project("Project Scene", "thor2d.project_scene")
	defer thor2d.Destroy_Project(&project)
	thor2d.Add_Project_Asset(&project, "assets/placeholder.txt", "text")
	fmt.println("project schema:", project.Schema_Version)
}
