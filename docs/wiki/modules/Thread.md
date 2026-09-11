# thor2d.Thread

Thor2D threads are for CPU/background work only. Worker procedures must not
touch `Context`, Raylib, Box2D world state, GPU resources or the main thread's
filesystem object. Send plain data through typed channels and apply results in
the game update callback.

## Channels

`New_Channel(T, capacity)` creates a typed channel. `Try_Send` and
`Try_Receive` never block; `Send` and `Receive` block according to the channel
contract; timeout variants return a success flag/error when the deadline is
reached. `Close_Channel` prevents further sends. `Destroy_Channel` releases the
channel after all users have stopped.

`Channel_Get_Count` reports queued items, `Channel_Has_Data` performs a
non-blocking readability check, and `Channel_Clear` drains queued items and
returns the count. `Channel_Peek` is intentionally `.Unsupported`: peeking by
pop-and-requeue would reorder messages under concurrent senders.

## Workers

`Start_Thread` starts a worker; `Start_Managed_Thread` additionally registers it
for lifecycle management. `Request_Thread_Cancel` asks a worker to stop;
`Thread_Cancelled` is cooperative and must be polled by the worker. `Join_Thread`
waits for completion, while `Join_Thread_Timeout` returns when the deadline is
reached. `Thread_State_Of`, `Thread_Done` and `Thread_Error_Of` provide status
without making a running thread safe to destroy.

`Register_Thread` attaches an externally-created thread to a context-managed
list. Registered threads are joined by the owning lifecycle; use it only when
the thread obeys the same no-Context/no-GPU rule.

```odin
messages, channel_err := thor2d.New_Channel(string, 8)
assert(channel_err == .None)
defer thor2d.Destroy_Channel(&messages)

// Worker code may send data, but never draws or mutates ctx.
thor2d.Try_Send(&messages, "background result")
if result, ok := thor2d.Try_Receive(&messages); ok {
    _ = result
}
```

Channel values and thread handles are owned resources. Close before destroy;
cancel and join workers before destroying data they reference.
