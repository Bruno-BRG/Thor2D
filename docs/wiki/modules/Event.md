# thor2d.Event

LOVE equivalent: `love.event`. Sources: `context.odin`.

## Description

Typed FIFO queue: `Push_Event/Poll_Event/Wait_Event/Clear_Events/Destroy_Event`, `Quit`, pumped by `Run/Poll_Events`.

## LOVE callback mapping (v0.10)

Every `love.*` callback has a Thor2D event path. Games handle them in `Game.On_Event` (called by `Run` per event) or by draining `Poll_Event` themselves; `Destroy_Event` frees the owned strings of dropped-file / text-edit events.

| LOVE callback | Thor2D `Event_Kind` | Fields | Source |
|---|---|---|---|
| `love.textinput(text)` | `Text_Input` | `Text: rune` | Backend `GetCharPressed` polling in `Poll_Events` (headless: never fires; `Push_Event` manually in tests) |
| `love.textedited(text, start, length)` | `Key_Text_Edited` | `Editing: string` (owned) | No IME API in the raylib backend — the kind exists and round-trips through the queue, but the backend never emits it; IME hosts should `Push_Event` compositions themselves |
| `love.filedropped(file)` | `File_Dropped` | `Path: string` (owned) | Backend `LoadDroppedFiles`; see below |
| `love.directorydropped(path)` | `Directory_Dropped` | `Path: string` (owned) | Raylib reports every drop as a file path; `Poll_Events` reclassifies real OS directories via `os.is_directory`, so LOVE `directorydropped` ports work |
| `love.keypressed/keyreleased` | `Key_Pressed/Key_Released` | `Key` | Backend key polling |
| `love.mousepressed/mousereleased/mousemoved/wheelmoved` | `Mouse_Button_Pressed/Released`, `Mouse_Moved`, `Mouse_Wheel` | `Mouse_Button`, `Position`, `Delta` | Backend mouse polling |
| `love.resize(w, h)` | `Window_Resized` | `Width, Height` | `IsWindowResized` |
| `love.focus(f)` / `love.visible(v)` | `Focus_Changed` / `Window_Visible` | `Focused` / `Visible` | Edge-triggered against stored backend state |
| `love.gamepadpressed/released/axis` | `Gamepad_Button_Pressed/Released`, `Gamepad_Axis_Moved` | `Device`, `Button`/`Axis`, `Value` | Backend gamepad polling |
| `love.joystickadded/removed` | `Joystick_Added/Removed` | `Device` | Edge-triggered availability |
| `love.touchpressed/released/moved` | `Touch_Pressed/Released/Moved` | `Touch_ID`, `Position` | Backend touch-ID tracking |
| `love.quit` | `Quit` | — | `WindowShouldClose`; also stops `Run` |

Drop events carry absolute OS paths (outside the filesystem sandbox by nature — validate before reading). Text-input state (`Set_Text_Input/Has_Text_Input`; `Is_Text_Input_Active` is intentionally the same proc, not an alias) only gates game-side handling; the backend emits `Text_Input` regardless. See [Keyboard](Keyboard.md) and [Mouse](Mouse.md).

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Timer](Timer.md)
