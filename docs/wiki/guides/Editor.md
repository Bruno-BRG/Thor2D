# Editor (v0.9 scaffolding)

`tools/editor_v09` is a standalone CLI project inspector (package
`editor_v09`, imports `thor2d` only) — the first slice of editor tooling.
It is intentionally windowless: it reads a `project.json`, validates it,
and prints a summary. Full scene editing remains future work.

```sh
./build.sh editor                       # builds bin/thor2d-editor-v09
./bin/thor2d-editor-v09 examples/love_port_v08
./bin/thor2d-editor-v09 path/to/project.json
```

With no argument it inspects `examples/love_port_v08`. The argument is a
project directory (appends `project.json`) or a direct `.json` path.

Output on success:

```text
project: thor2d.love-port.v08
name: Thor2D LOVE Port v0.8
assets: 0
scenes: 1
entities: 0
```

Validation uses `Decode_JSON` + `Validate_Project`, the same gate as the
runtime loader. Any failure (unreadable file, bad JSON, invalid project)
prints a `thor2d-editor:` message and exits non-zero.

## See Also

[Packaging](Packaging.md), [Capabilities](Capabilities.md).
