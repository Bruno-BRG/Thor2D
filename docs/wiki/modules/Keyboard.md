# thor2d.Keyboard

Keyboard polling is frame-based and belongs in `Update(ctx, delta)`. Events are
better for text and exact transitions.

## Polling

| Function | Meaning |
| --- | --- |
| `Key_Down` | True while a key is held. |
| `Key_Pressed` | True on the frame the key transitions up→down. |
| `Key_Released` | True on the frame the key transitions down→up. |
| `Key_Pressed_Repeat` | True for a press and OS-style repeat events when enabled. |
| `Is_Scancode_Down` | Polls a physical scancode instead of a layout key. |
| `Get_Key_From_Scancode` / `Get_Scancode_From_Key` | Converts between logical and physical identifiers. |
| `Set_Key_Repeat` / `Has_Key_Repeat` | Controls repeat event generation. |
| `Set_Text_Input` / `Has_Text_Input` | Enables committed text input collection. |

Invalid or unavailable devices return false/zero values; these functions do not
create synthetic key presses. All calls are safe in headless mode.

## Text and IME

Use `Event.Text_Input` for committed Unicode text, not key codes. An editing
composition arrives as `Key_Text_Edited`; its owned string must be released with
`Destroy_Event`. The Raylib desktop backend does not synthesize that IME event
itself; hosts may inject it through `Push_Event`.

```odin
update :: proc(ctx: ^thor2d.Context, delta: f32) {
    if thor2d.Key_Down(ctx, .Left) { player.X -= 240 * delta }
    if thor2d.Key_Pressed(ctx, .Escape) { thor2d.Quit(ctx) }
}
```

See [Event](Event.md), [Mouse](Mouse.md), [Joystick](Joystick.md) and the
[complete API reference](../Complete_API.md).
