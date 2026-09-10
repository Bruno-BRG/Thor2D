# thor2d.Thread

LOVE equivalent: `love.thread`. Sources: `threads.odin`.

## Description

Managed workers + typed `Channel(T)`: `Start_Thread/Start_Managed_Thread`, cancel, `Join_Thread(_Timeout)`, `Register_Thread` (auto-join in `Destroy`). Workers must not touch `Context`/GPU.

v0.10 channel introspection (LOVE `Channel:getCount/clear/hasRead` subset): `Channel_Get_Count` (real `core:sync/chan` length), `Channel_Has_Data` (non-blocking readability), `Channel_Clear` (drain, returns count, best-effort under concurrent senders). `Channel_Peek` always returns `.Unsupported`: peeking without popping has no primitive in `core:sync/chan`, and pop-and-requeue would reorder under concurrency — use `Try_Receive` + `Send` explicitly instead.

Wontfix by design: LOVE's `getChannel` string registry. Channels are typed `Channel(T)`; a heterogeneous string→channel registry would need type-erased storage where a wrong-type claim is memory-unsafe. Store named channels in a game-owned struct/map instead.

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Event](Event.md)
