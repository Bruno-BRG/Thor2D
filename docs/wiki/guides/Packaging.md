# Packaging

```sh
./build.sh project-check examples/love_port_v08
./build.sh pack examples/love_port_v08
./build.sh project-run build/love_port_v08.thor
```

Lookup order: save dir → project dir → mounted `.thor` archive. Manifest validated (schema, sizes, SHA-256) before launch.
