# thor2d.Mouse

LOVE equivalent: `love.mouse`. Sources: `input.odin`, `input_extra.odin`, `system.odin`.

## Description

`Mouse_Position/Set_Mouse_Position`, buttons, wheel, delta, `Set_Mouse_Relative/Get_Relative_Mode`, `Set_Mouse_Grab/Is_Mouse_Grabbed`, `Set_Cursor_Visible/Is_Cursor_Visible`, `Set_System_Cursor/Reset_Cursor`.

File/directory drops arrive as `File_Dropped` / `Directory_Dropped` events (raylib reports every drop as a file path; `Poll_Events` reclassifies real OS directories) — handle them in `Game.On_Event` or via `Poll_Event`, and `Destroy_Event` the owned `Path`. Full LOVE callback table: [Event](Event.md).

v0.9 custom cursor (mirrors `love.mouse.newCursor`): raylib has no
custom-OS-cursor API, so `Load_Cursor_From_Image(ctx, image, hot_x, hot_y)`
uploads the RGBA8 image as a `Texture`, hides the OS cursor, and returns
`Cursor{handle}` under a draw-it-yourself contract — the game draws it each
frame with `Draw_Texture` at `Mouse_Position` minus the hotspot, and calls
`Set_Cursor_Visible(ctx, true)` + `Unload_Cursor` when done. Hotspot must lie
inside the image (else `.Invalid_Data`); headless returns
`.Backend_Initialization_Failed`, never a fake handle. `Cursor_Invalid`
mirrors `Texture_Invalid`.

```odin
cursor, err := thor2d.Load_Cursor_From_Image(ctx, img, 0, 0)
if err == .None {
    thor2d.Draw_Texture(ctx, thor2d.Texture{cursor.handle}, thor2d.Mouse_Position(ctx))
    thor2d.Unload_Cursor(ctx, cursor)
}
```

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Touch](Touch.md)
