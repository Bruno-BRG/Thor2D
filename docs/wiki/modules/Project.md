# thor2d.Project

Project manifests describe assets and scenes for editor and package workflows.
The schema is intentionally small and can be validated without opening a
window.

```sh
./build.sh project-check examples/guide_game_v11
./build.sh pack examples/guide_game_v11
```

The complete procedure signatures are in [Api_Reference](../Api_Reference.md).
Manifest layout, hashes, lookup precedence and `.thor` archives are documented
in [Packaging](../guides/Packaging.md).
