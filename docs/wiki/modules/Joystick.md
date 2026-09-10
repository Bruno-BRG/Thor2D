# thor2d.Joystick

LOVE equivalent: `love.joystick`. Sources: `input.odin`, `input_extra.odin`.

## Description

`Gamepad_Available/Name/Axis/Button_Down/Pressed`, `Get_Joystick_Count`; mapping getters return `.Unsupported` (no mapping DB in raylib backend).

v0.9 completion (mirrors `love.joystick`): `Get_Joysticks(ctx)` returns
connected indices `0..<8` (temp allocator; LOVE returns objects, Thor2D
documents integer indices). `Get_Gamepad_GUID(ctx, i)` returns the documented
synthetic `"thor2d-gamepad-<index>"` with `.None` (raylib has no GUID API;
temp-allocator string). `Get_Gamepad_Axis_Count` returns 6 when available
else 0 (raylib `GamepadAxis` has 6 axes); `Get_Gamepad_Button_Count` returns
18 when available else 0 (backend polls 18 buttons). `Get_Gamepad_Hat`
returns `(0, .Unsupported)` (no hat API in backend — never faked).
`Set_Gamepad_Vibration(ctx, i, left, right)` clamps motors to 0..1 and calls
raylib `SetGamepadVibration` with a fixed 1.0s duration (call repeatedly for
longer rumble); `Stop_Gamepad_Vibration` cancels with zero motors.
Unavailable gamepad is `.Invalid_Handle`; headless is
`.Backend_Initialization_Failed`.

```odin
for i in thor2d.Get_Joysticks(ctx) {
    guid, _ := thor2d.Get_Gamepad_GUID(ctx, i)
    _ = guid
}
thor2d.Set_Gamepad_Vibration(ctx, 0, 1, 1)
thor2d.Stop_Gamepad_Vibration(ctx, 0)
```

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Keyboard](Keyboard.md)
