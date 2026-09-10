package thor2d

import "core:strings"
import backend "thor2d:thor2d/internal/raylib"

Key_Down :: proc(ctx: ^Context, key: Key) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Key_Down(ctx.backend, int(key))
}

Key_Pressed :: proc(ctx: ^Context, key: Key) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Key_Pressed(ctx.backend, int(key))
}

Key_Pressed_Repeat :: proc(ctx: ^Context, key: Key) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Key_Pressed_Repeat(ctx.backend, int(key))
}

Key_Released :: proc(ctx: ^Context, key: Key) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Key_Released(ctx.backend, int(key))
}

Mouse_Button_Down :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Mouse_Button_Down(ctx.backend, int(button))
}

Mouse_Button_Pressed :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Mouse_Button_Pressed(ctx.backend, int(button))
}

Mouse_Button_Released :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Mouse_Button_Released(ctx.backend, int(button))
}

Mouse_Position :: proc(ctx: ^Context) -> Vec2 {
	if ctx == nil || ctx.backend == nil {
		return Vec2{}
	}
	x, y := backend.Mouse_Position(ctx.backend)
	return Vec2{x, y}
}

Mouse_Wheel :: proc(ctx: ^Context) -> f32 {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	return backend.Mouse_Wheel(ctx.backend)
}

Mouse_Delta :: proc(ctx: ^Context) -> Vec2 {
	if ctx == nil || ctx.backend == nil {
		return Vec2{}
	}
	x, y := backend.Mouse_Delta(ctx.backend)
	return Vec2{x, y}
}

Set_Mouse_Relative :: proc(ctx: ^Context, relative: bool) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	backend.Set_Mouse_Relative(ctx.backend, relative)
	ctx.relative_mode = relative
	return .None
}

Gamepad_Available :: proc(ctx: ^Context, index: int) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Gamepad_Available(ctx.backend, index)
}

Gamepad_Axis :: proc(ctx: ^Context, index, axis: int) -> f32 {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	return backend.Gamepad_Axis(ctx.backend, index, axis)
}

Gamepad_Name :: proc(ctx: ^Context, index: int) -> string {
	if ctx == nil || ctx.backend == nil {
		return ""
	}
	return backend.Gamepad_Name(ctx.backend, index)
}

Gamepad_Button_Down :: proc(ctx: ^Context, index, button: int) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Gamepad_Button_Down(ctx.backend, index, button)
}

Gamepad_Button_Pressed :: proc(ctx: ^Context, index, button: int) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Gamepad_Button_Pressed(ctx.backend, index, button)
}

Touch_Count :: proc(ctx: ^Context) -> int {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	return backend.Touch_Count(ctx.backend)
}

Touch_Position :: proc(ctx: ^Context, index: int) -> Vec2 {
	if ctx == nil || ctx.backend == nil {
		return Vec2{}
	}
	x, y := backend.Touch_Position(ctx.backend, index)
	return Vec2{x, y}
}

New_Action_Map :: proc(dead_zone := f32(0.15)) -> Action_Map {
	return Action_Map{Bindings = make(map[string][dynamic]Action_Binding), Dead_Zone = Clamp(dead_zone, 0, 0.99)}
}

Destroy_Action_Map :: proc(action_map: ^Action_Map) {
	if action_map == nil {
		return
	}
	for name, bindings in action_map.Bindings {
		delete(name)
		delete(bindings)
	}
	delete(action_map.Bindings)
	action_map^ = Action_Map{}
}

Bind_Action :: proc(action_map: ^Action_Map, name: string, binding: Action_Binding) -> Error {
	if action_map == nil || name == "" {
		return .Invalid_Config
	}
	if action_map.Bindings == nil {
		action_map.Bindings = make(map[string][dynamic]Action_Binding)
	}
	owned_name, clone_err := strings.clone(name)
	if clone_err != nil {
		return .Invalid_Data
	}
	bindings, exists := action_map.Bindings[name]
	if !exists {
		bindings = make([dynamic]Action_Binding, 0, context.allocator)
	}
	value := binding
	if value.Scale == 0 {
		value.Scale = 1
	}
	append(&bindings, value)
	if exists {
		// The existing key owns its string. The temporary clone is discarded.
		delete(owned_name)
	} else {
		action_map.Bindings[owned_name] = bindings
	}
	if exists {
		action_map.Bindings[name] = bindings
	}
	return .None
}

Bind_Action_Key :: proc(action_map: ^Action_Map, name: string, key: Key, scale := f32(1)) -> Error {
	return Bind_Action(action_map, name, Action_Binding{Kind = .Key, Code = int(key), Scale = scale})
}

Bind_Action_Mouse :: proc(action_map: ^Action_Map, name: string, button: Mouse_Button, scale := f32(1)) -> Error {
	return Bind_Action(action_map, name, Action_Binding{Kind = .Mouse_Button, Code = int(button), Scale = scale})
}

Bind_Action_Gamepad_Button :: proc(action_map: ^Action_Map, name: string, button: int, scale := f32(1)) -> Error {
	return Bind_Action(action_map, name, Action_Binding{Kind = .Gamepad_Button, Code = button, Scale = scale})
}

Bind_Action_Gamepad_Axis :: proc(action_map: ^Action_Map, name: string, axis: int, sign := f32(1), scale := f32(1)) -> Error {
	return Bind_Action(action_map, name, Action_Binding{Kind = .Gamepad_Axis, Code = axis, Axis_Sign = sign, Scale = scale})
}

Action_Value :: proc(ctx: ^Context, action_map: ^Action_Map, name: string, gamepad := 0) -> f32 {
	if ctx == nil || action_map == nil || action_map.Bindings == nil {
		return 0
	}
	bindings, ok := action_map.Bindings[name]
	if !ok {
		return 0
	}
	result: f32
	for binding in bindings {
		value: f32
		switch binding.Kind {
		case .Key:
			if Key_Down(ctx, Key(binding.Code)) {
				value = 1
			}
		case .Mouse_Button:
			if Mouse_Button_Down(ctx, Mouse_Button(binding.Code)) {
				value = 1
			}
		case .Gamepad_Button:
			if ctx.backend != nil && backend.Gamepad_Button_Down(ctx.backend, gamepad, binding.Code) {
				value = 1
			}
		case .Gamepad_Axis:
			value = Gamepad_Axis(ctx, gamepad, binding.Code)
			if binding.Axis_Sign != 0 {
				value *= binding.Axis_Sign
			}
			if Abs_F32(value) < action_map.Dead_Zone {
				value = 0
			}
		}
		result += value * binding.Scale
	}
	return Clamp(result, -1, 1)
}

Action_Pressed :: proc(ctx: ^Context, action_map: ^Action_Map, name: string, gamepad := 0) -> bool {
	if ctx == nil || action_map == nil {
		return false
	}
	bindings, ok := action_map.Bindings[name]
	if !ok {
		return false
	}
	for binding in bindings {
		switch binding.Kind {
		case .Key:
			if Key_Pressed(ctx, Key(binding.Code)) {
				return true
			}
		case .Mouse_Button:
			if Mouse_Button_Pressed(ctx, Mouse_Button(binding.Code)) {
				return true
			}
		case .Gamepad_Button:
			if ctx.backend != nil && backend.Gamepad_Button_Pressed(ctx.backend, gamepad, binding.Code) {
				return true
			}
		case .Gamepad_Axis:
			// Axes are continuous values and do not have a pressed edge.
		}
	}
	return false
}
