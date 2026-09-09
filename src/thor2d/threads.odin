package thor2d

import sync_chan "core:sync/chan"
import odin_thread "core:thread"
import "base:intrinsics"
import "core:time"

Channel_Direction_Default :: sync_chan.Direction.Both

Channel :: struct($T: typeid) {
	inner: sync_chan.Chan(T),
}

New_Channel :: proc($T: typeid, capacity: int) -> (Channel(T), Error) {
	if capacity < 0 {
		return Channel(T){}, .Invalid_Config
	}
	inner, err := sync_chan.create_buffered(sync_chan.Chan(T), max(capacity, 1), context.allocator)
	if err != nil {
		return Channel(T){}, .Resource_Load_Failed
	}
	return Channel(T){inner = inner}, .None
}

Destroy_Channel :: proc(channel: ^Channel($T)) {
	if channel != nil && channel.inner.impl != nil {
		sync_chan.close(channel.inner.impl)
		sync_chan.destroy(channel.inner.impl)
		channel.inner = sync_chan.Chan(T){}
	}
}

Close_Channel :: proc(channel: ^Channel($T)) {
	Destroy_Channel(channel)
}

Send :: proc(channel: ^Channel($T), value: T) -> bool {
	return channel != nil && channel.inner.impl != nil && sync_chan.send(channel.inner, value)
}

Try_Send :: proc(channel: ^Channel($T), value: T) -> bool {
	return channel != nil && channel.inner.impl != nil && sync_chan.try_send(channel.inner, value)
}

Receive :: proc(channel: ^Channel($T)) -> (T, bool) {
	if channel == nil || channel.inner.impl == nil {
		return T{}, false
	}
	return sync_chan.recv(channel.inner)
}

Try_Receive :: proc(channel: ^Channel($T)) -> (T, bool) {
	if channel == nil || channel.inner.impl == nil {
		return T{}, false
	}
	return sync_chan.try_recv(channel.inner)
}

Send_Timeout :: proc(channel: ^Channel($T), value: T, timeout: time.Duration) -> bool {
	if channel == nil || channel.inner.impl == nil {
		return false
	}
	if timeout <= 0 {
		return sync_chan.try_send(channel.inner, value)
	}
	start := time.tick_now()
	for time.tick_diff(start, time.tick_now()) < timeout {
		if sync_chan.try_send(channel.inner, value) {
			return true
		}
		time.sleep(time.Millisecond)
	}
	return false
}

Receive_Timeout :: proc(channel: ^Channel($T), timeout: time.Duration) -> (T, bool) {
	if channel == nil || channel.inner.impl == nil {
		return T{}, false
	}
	if timeout <= 0 {
		return sync_chan.try_recv(channel.inner)
	}
	start := time.tick_now()
	for time.tick_diff(start, time.tick_now()) < timeout {
		if value, ok := sync_chan.try_recv(channel.inner); ok {
			return value, true
		}
		time.sleep(time.Millisecond)
	}
	return T{}, false
}

Push :: proc(channel: ^Channel($T), value: T) -> bool {
	return Send(channel, value)
}

Pop :: proc(channel: ^Channel($T)) -> (T, bool) {
	return Receive(channel)
}

Demand :: proc(channel: ^Channel($T)) -> (T, bool) {
	return Receive(channel)
}

Supply :: proc(channel: ^Channel($T), value: T) -> bool {
	return Send(channel, value)
}

Thread :: struct {
	native: ^odin_thread.Thread,
	managed: ^Managed_Thread_Data,
}

Thread_State :: enum u32 {
	Created,
	Running,
	Finished,
	Cancelled,
	Failed,
	Joined,
}

Thread_Error :: struct {
	Code: Error,
}

Thread_Control :: struct {
	cancelled: u32,
}

Managed_Thread_Proc :: #type proc(control: ^Thread_Control) -> Error

Managed_Thread_Data :: struct {
	control: ^Thread_Control,
	state: ^u32,
	error_code: ^u32,
	procedure: Managed_Thread_Proc,
}

managed_thread_entry :: proc(native: ^odin_thread.Thread) {
	if native == nil || native.data == nil {
		return
	}
	data := cast(^Managed_Thread_Data)native.data
	intrinsics.atomic_store(data.state, u32(Thread_State.Running))
	err := data.procedure(data.control)
	intrinsics.atomic_store(data.error_code, u32(err))
	state := Thread_State.Finished
	if err != .None {
		state = .Failed
	} else if intrinsics.atomic_load(&data.control.cancelled) != 0 {
		state = .Cancelled
	}
	intrinsics.atomic_store(data.state, u32(state))
}

Start_Thread :: proc(procedure: odin_thread.Thread_Proc, name := "thor2d-worker") -> (Thread, Error) {
	if !odin_thread.IS_SUPPORTED {
		return Thread{}, .Unsupported
	}
	native := odin_thread.create(procedure, .Normal, name)
	if native == nil {
		return Thread{}, .Resource_Load_Failed
	}
	odin_thread.start(native)
	return Thread{native = native}, .None
}

// Start_Managed_Thread provides a cooperative cancellation token. The worker
// must check Thread_Cancelled(control) at safe points and return normally.
Start_Managed_Thread :: proc(procedure: Managed_Thread_Proc, name := "thor2d-worker") -> (Thread, Error) {
	if !odin_thread.IS_SUPPORTED || procedure == nil {
		return Thread{}, .Unsupported
	}
	control := new(Thread_Control)
	state := new(u32)
	error_code := new(u32)
	intrinsics.atomic_store(state, u32(Thread_State.Created))
	data := new(Managed_Thread_Data)
	data^ = Managed_Thread_Data{control = control, state = state, error_code = error_code, procedure = procedure}
	native := odin_thread.create(managed_thread_entry, .Normal, name)
	if native == nil {
		free(data)
		free(error_code)
		free(state)
		free(control)
		return Thread{}, .Resource_Load_Failed
	}
	native.data = rawptr(data)
	odin_thread.start(native)
	return Thread{native = native, managed = data}, .None
}

Request_Thread_Cancel :: proc(thread: ^Thread) {
	if thread != nil && thread.managed != nil {
		intrinsics.atomic_store(&thread.managed.control.cancelled, 1)
	}
}

Thread_Cancelled :: proc(control: ^Thread_Control) -> bool {
	return control != nil && intrinsics.atomic_load(&control.cancelled) != 0
}

Thread_State_Of :: proc(thread: ^Thread) -> Thread_State {
	if thread == nil {
		return .Joined
	}
	if thread.managed != nil && thread.managed.state != nil {
		return Thread_State(intrinsics.atomic_load(thread.managed.state))
	}
	if thread.native == nil {
		return .Joined
	}
	if odin_thread.is_done(thread.native) {
		return .Finished
	}
	return .Running
}

Thread_Error_Of :: proc(thread: ^Thread) -> Thread_Error {
	if thread == nil || thread.managed == nil || thread.managed.error_code == nil {
		return Thread_Error{}
	}
	return Thread_Error{Code = Error(intrinsics.atomic_load(thread.managed.error_code))}
}

Join_Thread :: proc(thread: ^Thread) {
	if thread != nil && thread.native != nil {
		odin_thread.destroy(thread.native)
		thread.native = nil
	}
	if thread != nil && thread.managed != nil {
		free(thread.managed.error_code)
		free(thread.managed.state)
		free(thread.managed.control)
		free(thread.managed)
		thread.managed = nil
	}
}

Join_Thread_Timeout :: proc(thread: ^Thread, timeout: time.Duration) -> bool {
	if thread == nil || thread.native == nil {
		return true
	}
	if !odin_thread.is_done(thread.native) {
		if timeout <= 0 {
			return false
		}
		start := time.tick_now()
		for !odin_thread.is_done(thread.native) && time.tick_diff(start, time.tick_now()) < timeout {
			time.sleep(time.Millisecond)
		}
	}
	if !odin_thread.is_done(thread.native) {
		return false
	}
	Join_Thread(thread)
	return true
}

Thread_Done :: proc(thread: ^Thread) -> bool {
	return thread != nil && thread.native != nil && odin_thread.is_done(thread.native)
}

Stop_Thread :: proc(thread: ^Thread) {
	if thread != nil && thread.managed != nil {
		Request_Thread_Cancel(thread)
	} else if thread != nil && thread.native != nil && !odin_thread.is_done(thread.native) {
		odin_thread.terminate(thread.native, 0)
	}
}
