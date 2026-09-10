# thor2d.Keyboard

LOVE equivalent: `love.keyboard`. Sources: `input.odin`, `input_extra.odin`.

## Description

`Key_Down/Pressed/Released`, `Key_Pressed_Repeat`, `Set_Key_Repeat/Has_Key_Repeat`, `Set_Text_Input/Has_Text_Input`, scancode helpers.

IME and text flow through events, not polling: `Text_Input` events carry committed runes (`Event.Text`), and `Key_Text_Edited` carries the in-progress composition (`Event.Editing`, owned string — `Destroy_Event` it). The backend has no IME API, so `Key_Text_Edited` never fires from the backend itself; IME hosts `Push_Event` compositions. `Is_Text_Input_Active` is intentionally not a separate proc — it is `Has_Text_Input`. Full LOVE callback table: [Event](Event.md).

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Mouse](Mouse.md)
