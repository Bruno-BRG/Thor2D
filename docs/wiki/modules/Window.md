# thor2d.Window

LOVE equivalent: `love.window`. Sources: `context.odin`, `system.odin`, `window.odin`.

## Description

Desktop window management over raylib. Size/title/fullscreen are set at
`Create`; runtime toggles apply immediately. All queries are headless-safe.

## Types

`Display_Mode`, `Display_Info`.

## Functions

- `Window_Size(ctx)` / `Set_Window_Size(ctx, w, h)` — LOVE `getMode/setMode` subset.
- `Set_Window_Title(ctx, t)` / `Window_Title(ctx)` — LOVE `setTitle` (+ getter).
- `Window_Is_Open(ctx)` / `Close_Window(ctx)` — LOVE `isOpen/close` (`Close` stops `Run`).
- `Window_Is_Fullscreen(ctx)` / `Set_Fullscreen(ctx, b)` / `Toggle_Fullscreen(ctx)` — LOVE fullscreen.
- `Window_Is_Visible(ctx)` / `Window_Has_Focus(ctx)` / `Window_Has_Mouse_Focus(ctx)` — LOVE `isVisible/hasFocus/hasMouseFocus`.
- `Window_Is_Minimized(ctx)` / `Window_Is_Maximized(ctx)` / `Maximize_Window` / `Minimize_Window` / `Restore_Window` — LOVE `isMinimized/isMaximized/maximize/minimize/restore`.
- `Get_Window_Mode(ctx)` — `(w, h, fullscreen, resizable, vsync)`; LOVE `getMode` subset.
- `Update_Window_Mode(ctx, w, h, fullscreen, resizable, vsync)` — LOVE `setMode` subset. Size/fullscreen apply immediately via `Set_Window_Size`/`Set_Fullscreen` when a backend exists; resizable/vsync are stored in `ctx.config` (raylib fixes both at creation, so they need a restart). Returns `.None` applying what is possible, never fakes; headless stores config and returns `.None`. Non-positive size is `.Invalid_Config`.
- `Get_VSync(ctx)` / `Set_VSync(ctx, b)` — LOVE `getVSync/setVSync`. Setter stores the flag and returns `.Unsupported` (raylib fixes vsync at creation).
- `Window_Position(ctx)` / `Set_Window_Position(ctx, p)` — LOVE `getPosition/setPosition`.
- `Window_DPI_Scale(ctx)` — LOVE `getDPIScale`.
- `Desktop_Size(ctx)` / `Current_Display_Mode(ctx)` — LOVE `getDesktopDimensions`.
- `Get_Display_Count(ctx)` / `Get_Display_Info(ctx, i)` — LOVE `getDisplayCount/getDisplayName`.
- `Get_Safe_Area(ctx)` — LOVE `getSafeArea` (full window on desktop).
- `Set_Window_Icon(ctx, image)` — LOVE `setIcon` (RGBA8 `Image_Data`).
- `Show_Message_Box(ctx, title, msg)` → `.Unsupported` — LOVE `showMessageBox`.
- `Set_Cursor_Visible(ctx, b)` / `Is_Cursor_Visible(ctx)`, `Set_Mouse_Grab(ctx, b)` / `Is_Mouse_Grabbed(ctx)` — LOVE `setGrabbed` family.
- `Get_Fullscreen_Modes(ctx)` — LOVE `getFullscreenModes`: one `Display_Mode` per monitor from `Get_Display_Info`; `Refresh_Rate` is filled from `Current_Display_Mode` when dimensions match, else `0` (unknown, never guessed).
- `Window_Has_Icon(ctx)` — whether `Set_Window_Icon` has succeeded (stored flag; the backend has no icon getter).
- `Request_Attention(ctx)` → `.Unsupported` — LOVE `requestAttention` (no taskbar-flash API in the raylib backend; verified against `vendor/raylib`).
- `Is_Display_Sleep_Enabled(ctx)` — getter for the `Set_Display_Sleep_Enabled` intent (default true; stored intent, not OS state).

## Mobile (v0.9 scaffolding)

- `Get_Display_Orientation(ctx)` — `"landscape"` / `"portrait"` /
  `"unknown"`. Desktop derives it from the window aspect (width >= height
  is landscape); headless (or nil ctx) is `"unknown"`. A mobile backend
  will report the sensor orientation.
- `Set_Display_Sleep_Enabled(ctx, enabled)` — mobile-future stub
  (`false` = keep the screen awake). Desktop always returns `.Unsupported`.
- See [Mobile](../guides/Mobile.md).

```odin
orientation := thor2d.Get_Display_Orientation(ctx) // "unknown" headless
if thor2d.Set_Display_Sleep_Enabled(ctx, false) == .Unsupported {
    // Desktop: nothing to keep awake.
}
```

## Examples

```odin
title := thor2d.Window_Title(ctx)
w, h, fs, _, _ := thor2d.Get_Window_Mode(ctx)
if !thor2d.Window_Has_Focus(ctx) { return }
```

## See Also

[System](System.md), [Graphics](Graphics.md).
