# Mobile

Thor2D is desktop-first (Linux AMD64 primary). This page collects the
mobile-future surface added in v0.9: stubs that compile and run on desktop
today, report honestly, and will light up under a future mobile backend
without changing game code.

## Vibration

`Vibrate(seconds)` (see [System](../modules/System.md), mirrors
`love.system.vibrate`) requests a device buzz. Desktop has no vibration
hardware, so any positive duration returns `.Unsupported`; non-positive
durations are `.Invalid_Data`. A mobile backend will vibrate and return
`.None`. Games should treat `.Unsupported` as "no haptics here" and carry
on — never gate gameplay on it.

```odin
if thor2d.Vibrate(0.2) == .Unsupported {
    // Desktop: flash the screen or play a click instead.
}
```

## Orientation and display sleep

`Get_Display_Orientation(ctx)` (see [Window](../modules/Window.md)) reports
`"landscape"`, `"portrait"` or `"unknown"`. Desktop derives it from the
window aspect (width >= height is landscape); headless is `"unknown"`. A
mobile backend will report the sensor orientation instead.

`Set_Display_Sleep_Enabled(ctx, enabled)` asks the OS whether the display
may sleep (`false` = keep the screen awake during play). Desktop always
returns `.Unsupported`; a mobile backend will honor it.

## Portability rules

- Probe, don't assume: `Vibrate` / `Set_Display_Sleep_Enabled` returning
  `.Unsupported` is the normal desktop answer, not an error to crash on.
- `Get_Display_Orientation` returning `"unknown"` means "lay out for any
  aspect" — keep HUD anchoring aspect-independent.
- No mobile backend exists yet: there is no export, packaging, or store
  flow. Editor and packaging workflows stay desktop CLI (see
  [Editor](Editor.md), [Packaging](Packaging.md)).
