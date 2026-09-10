# thor2d.Net

LOVE equivalent: none built in — LOVE ships no networking; games use
third-party `enet` / `luasocket` bindings. Sources: `net.odin`, `types.odin`
(`Error.Not_Ready`).

## Description

Minimal non-blocking TCP+UDP surface on portable `core:net` (Linux AMD64
primary, no OS-specific code: `core:net` owns the platform split). Every
socket is switched to non-blocking mode before it is returned — if that
switch fails the socket is closed and an error is returned, so a blocking
socket can never stall `Update`. Everything is headless-safe: loopback
works with no window or GPU.

Polling contract: `TCP_Accept` with no pending peer, and `TCP_Send` /
`TCP_Receive` / `UDP_Receive_From` with no buffer space or data, return
`Error.Not_Ready` (`Error_String`: "non-blocking operation is not ready
yet; try again later"). Poll again on a later frame; `.Not_Ready` is never
a failure. `TCP_Receive` returning `(0, .None)` means the peer closed
gracefully — distinct from `(0, .Not_Ready)` (no data yet).

Slow paths: `TCP_Connect` performs one blocking connect and `Net_Resolve`
may do blocking DNS. Prefer IP literals (`"127.0.0.1"` takes a parse
fast-path with no DNS) and call them from `Load`, never every frame.

## Types

`Net_Address` (`Host: string`, `Port: int`), `TCP_Listener`, `TCP_Stream`,
`UDP_Socket`.

Ownership: `Net_Address` values passed IN borrow `Host` (never freed by
thor2d). The `from` address returned by `UDP_Receive_From` owns a cloned
`Host`: free it with `delete()`.

## Functions

- `Net_Resolve(host, port)` — validate an address (`IP` fast-path, else OS
  DNS). Bad input is `.Invalid_Data`; the returned `Host` aliases the input.
- `TCP_Listen(address)` — bind + listen (port 0 = ephemeral). Never fakes.
- `TCP_Accept(l)` — one pending peer, or `(TCP_Stream{}, .Not_Ready)`.
- `TCP_Connect(address)` — dial (blocking, prefer IP literals) then go
  non-blocking. Refused/unreachable is `.Resource_Load_Failed`.
- `TCP_Send(stream, data)` / `TCP_Receive(stream, data)` — `(n, Error)`;
  full buffers are `(n, .Not_Ready)`, graceful close is `(0, .None)`.
- `TCP_Close_Listener(l)` / `TCP_Close_Stream(s)` / `TCP_Close` (group over
  both) — nil-safe, idempotent shutdown.
- `UDP_Open(port)` — bind non-blocking UDP on all interfaces (0 = ephemeral).
- `UDP_Send_To(socket, data, address)` — one datagram; full buffer is `.Not_Ready`.
- `UDP_Receive_From(socket, data)` — `(n, from, Error)`; empty queue is
  `(0, Net_Address{}, .Not_Ready)`; `from.Host` is caller-owned.
- `UDP_Close(socket)` — nil-safe, idempotent shutdown.

## Examples

```odin
listener, err := thor2d.TCP_Listen(thor2d.Net_Address{Host = "127.0.0.1", Port = 17421})
if err != .None { return }
defer thor2d.TCP_Close(&listener)

// ... each frame: accept peers without blocking ...
peer, aerr := thor2d.TCP_Accept(&listener)
if aerr == .None {
    n, rerr := thor2d.TCP_Receive(&peer, buf)
    if rerr == .None && n > 0 { thor2d.TCP_Send(&peer, buf[:n]) } // echo
}
// aerr == .Not_Ready simply means "no peer yet".
```

See `examples/net_echo_v09` for a complete headless ping/echo round-trip.

## See Also

[System](System.md), [Thread](../guides/Capabilities.md).
