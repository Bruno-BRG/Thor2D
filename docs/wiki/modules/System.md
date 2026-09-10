# thor2d.System

LOVE equivalent: `love.system`. Sources: `system.odin`, `window.odin`.

## Description

`Operating_System`, `Processor_Count`, clipboard, `Open_URL`, `Locale`, `Get_Power_Info`, metrics, `Sleep`.

v0.9 version (mirrors `love.getVersion` / `love.isVersionCompatible`):
`THOR2D_VERSION_MAJOR/MINOR/PATCH` are `0/9/0`; `Thor2D_Version()` returns
`(major, minor, patch)`; `Is_Version_Compatible(major, minor)` is true for
the same major with requested minor `<=` current minor.

```odin
major, minor, _ := thor2d.Thor2D_Version()
ok := thor2d.Is_Version_Compatible(major, minor)
```

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## Mobile (v0.9 scaffolding)

- `Vibrate(seconds)` — mobile-future stub mirroring `love.system.vibrate`.
  Desktop has no vibration hardware: positive durations return
  `.Unsupported`, non-positive durations are `.Invalid_Data`. A future
  mobile backend will vibrate and return `.None`. See
  [Mobile](../guides/Mobile.md).

```odin
if thor2d.Vibrate(0.2) == .Unsupported {
    // No haptics on desktop; use a visual/audio cue instead.
}
```

## See Also

[Window](Window.md)
