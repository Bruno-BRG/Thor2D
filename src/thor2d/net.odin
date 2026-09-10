package thor2d

// v0.9 minimal non-blocking TCP+UDP surface (no LOVE equivalent: LOVE ships
// no networking; games use third-party enet/luasocket bindings).
//
// Implemented purely on portable `core:net` (+ `core:strings` for the
// UDP sender address), so no `when ODIN_OS` branches are needed: core:net
// owns the Linux/Windows/Darwin split. Linux AMD64 is the primary target.
//
// Non-blocking rules (the module never blocks `Update`):
// - Every socket is switched to non-blocking mode before it is returned.
//   If that switch fails the socket is closed and an error is returned,
//   so a blocking socket can never leak into game code.
// - `TCP_Accept` with no pending peer, and `TCP_Send`/`TCP_Receive`/
//   `UDP_Receive_From` with no buffer space/data, return `.Not_Ready`.
//   Poll again on a later frame; `.Not_Ready` is never a failure.
// - `TCP_Receive` returning `(0, .None)` means the peer closed gracefully
//   (mirrors `core:net` semantics), distinct from `(0, .Not_Ready)`.
// - `TCP_Connect` performs one blocking connect, and `Net_Resolve` may do
//   blocking DNS: both can be slow. Prefer IP literals (`"127.0.0.1"` takes
//   a parse fast-path with no DNS), and call them from `Load` or sparingly,
//   never every frame.
// - Everything is headless-safe: loopback works with no window or GPU.
//
// Ownership: `Net_Address` values you pass IN borrow their `Host` string
// (never freed by thor2d). The `from` address RETURNED by
// `UDP_Receive_From` owns a cloned `Host` string: free it with `delete()`.

import net "core:net"
import "core:strings"

// Net_Address identifies a TCP/UDP peer or bind target. Use IP literals
// (`"127.0.0.1"`, `"::1"`) where possible; hostnames trigger DNS.
Net_Address :: struct {
	Host: string,
	Port: int,
}

// TCP_Listener is a bound, listening, non-blocking server socket.
TCP_Listener :: struct {
	socket: net.TCP_Socket,
	closed: bool,
}

// TCP_Stream is one connected, non-blocking TCP connection (client side
// from TCP_Connect, server side from TCP_Accept).
TCP_Stream :: struct {
	socket: net.TCP_Socket,
	closed: bool,
}

// UDP_Socket is a bound, non-blocking UDP socket (connectionless:
// use UDP_Send_To/UDP_Receive_From with explicit addresses).
UDP_Socket :: struct {
	socket: net.UDP_Socket,
	closed: bool,
}

// Net_Resolve validates `host`+`port` for later dial/send use. IP literals
// resolve without DNS; hostnames resolve via the OS resolver (may block).
// The returned `Host` aliases the input string: no allocation, nothing to
// free. Invalid host/port maps to `.Invalid_Data`.
Net_Resolve :: proc(host: string, port: int) -> (Net_Address, Error) {
	if len(host) == 0 || port <= 0 || port > 65535 {
		return {}, .Invalid_Data
	}
	if _, ok := net.parse_ip4_address(host); ok {
		return Net_Address{Host = host, Port = port}, .None
	}
	if _, ok := net.parse_ip6_address(host); ok {
		return Net_Address{Host = host, Port = port}, .None
	}
	ep4, ep6, resolve_err := net.resolve(host)
	if resolve_err != nil {
		return {}, .Invalid_Data
	}
	endpoint := ep4 if ep4.address != nil else ep6
	if endpoint.address == nil {
		return {}, .Invalid_Data
	}
	return Net_Address{Host = host, Port = port}, .None
}

// TCP_Listen binds and listens on `address` (port 0 = OS-assigned
// ephemeral). The socket is non-blocking before return. Failures
// (in use, permission, bad address) map to explicit errors, never a
// fake listener.
TCP_Listen :: proc(address: Net_Address) -> (TCP_Listener, Error) {
	endpoint, resolve_err := _net_to_endpoint(address)
	if resolve_err != .None {
		return {}, resolve_err
	}
	sock, listen_err := net.listen_tcp(endpoint)
	if listen_err != nil {
		return {}, _net_map_error(listen_err)
	}
	if blocking_err := net.set_blocking(sock, false); blocking_err != nil {
		net.close(sock)
		return {}, _net_map_error(blocking_err)
	}
	return TCP_Listener{socket = sock}, .None
}

// TCP_Accept takes one pending peer, or `(TCP_Stream{}, .Not_Ready)` when
// the queue is empty. The accepted stream is non-blocking before return.
TCP_Accept :: proc(l: ^TCP_Listener) -> (TCP_Stream, Error) {
	if l == nil || l.closed || i64(l.socket) == 0 {
		return {}, .Invalid_Handle
	}
	client, _, accept_err := net.accept_tcp(l.socket)
	if accept_err != nil {
		if accept_err == .Would_Block || accept_err == .Timeout {
			return {}, .Not_Ready
		}
		return {}, _net_map_error(accept_err)
	}
	if blocking_err := net.set_blocking(client, false); blocking_err != nil {
		net.close(client)
		return {}, _net_map_error(blocking_err)
	}
	return TCP_Stream{socket = client}, .None
}

// TCP_Connect dials `address` (port 1..65535) and returns a non-blocking
// stream. The dial itself blocks briefly and DNS may be slow: prefer IP
// literals and call from `Load`, not per-frame. Refused/unreachable maps
// to `.Resource_Load_Failed`, never a fake stream.
TCP_Connect :: proc(address: Net_Address) -> (TCP_Stream, Error) {
	if address.Port <= 0 || address.Port > 65535 {
		return {}, .Invalid_Data
	}
	endpoint, resolve_err := _net_to_endpoint(address)
	if resolve_err != .None {
		return {}, resolve_err
	}
	sock, dial_err := net.dial_tcp_from_endpoint(endpoint)
	if dial_err != nil {
		return {}, _net_map_error(dial_err)
	}
	if blocking_err := net.set_blocking(sock, false); blocking_err != nil {
		net.close(sock)
		return {}, _net_map_error(blocking_err)
	}
	return TCP_Stream{socket = sock}, .None
}

// TCP_Send writes `data` (empty = `(0, .None)` no-op). A full buffer maps
// to `(n, .Not_Ready)` with `n` bytes accepted so far; resend the rest
// later. Dead peers map to `.Resource_Load_Failed`.
TCP_Send :: proc(stream: ^TCP_Stream, data: []byte) -> (int, Error) {
	if stream == nil || stream.closed || i64(stream.socket) == 0 {
		return 0, .Invalid_Handle
	}
	if len(data) == 0 {
		return 0, .None
	}
	written, send_err := net.send_tcp(stream.socket, data)
	if send_err != nil {
		if send_err == .Would_Block || send_err == .Timeout {
			return written, .Not_Ready
		}
		return written, _net_map_error(send_err)
	}
	return written, .None
}

// TCP_Receive fills `data`, returning bytes read. `(0, .Not_Ready)` = no
// data yet; `(0, .None)` = peer closed gracefully.
TCP_Receive :: proc(stream: ^TCP_Stream, data: []byte) -> (int, Error) {
	if stream == nil || stream.closed || i64(stream.socket) == 0 {
		return 0, .Invalid_Handle
	}
	if len(data) == 0 {
		return 0, .Invalid_Data
	}
	read, recv_err := net.recv_tcp(stream.socket, data)
	if recv_err != nil {
		if recv_err == .Would_Block || recv_err == .Timeout {
			return 0, .Not_Ready
		}
		return read, _net_map_error(recv_err)
	}
	return read, .None
}

// TCP_Close_Listener shuts a listener down. Nil-safe and idempotent.
TCP_Close_Listener :: proc(l: ^TCP_Listener) {
	if l == nil || l.closed {
		return
	}
	l.closed = true
	if i64(l.socket) != 0 {
		net.close(l.socket)
		l.socket = 0
	}
}

// TCP_Close_Stream shuts one connection down. Nil-safe and idempotent.
TCP_Close_Stream :: proc(s: ^TCP_Stream) {
	if s == nil || s.closed {
		return
	}
	s.closed = true
	if i64(s.socket) != 0 {
		net.close(s.socket)
		s.socket = 0
	}
}

// TCP_Close closes a listener or a stream (proc group over
// TCP_Close_Listener / TCP_Close_Stream).
TCP_Close :: proc {
	TCP_Close_Listener,
	TCP_Close_Stream,
}

// UDP_Open binds a non-blocking UDP socket on `port` (0 = ephemeral,
// OS-assigned) on all interfaces, so loopback peers can reach it.
UDP_Open :: proc(port: int) -> (UDP_Socket, Error) {
	if port < 0 || port > 65535 {
		return {}, .Invalid_Data
	}
	sock, make_err := net.make_bound_udp_socket(net.IP4_Any, port)
	if make_err != nil {
		return {}, _net_map_error(make_err)
	}
	udp := sock
	if blocking_err := net.set_blocking(udp, false); blocking_err != nil {
		net.close(udp)
		return {}, _net_map_error(blocking_err)
	}
	return UDP_Socket{socket = udp}, .None
}

// UDP_Send_To sends one datagram to `address` (empty data = `(0, .None)`
// no-op). A full send buffer maps to `(0, .Not_Ready)`; retry later.
UDP_Send_To :: proc(socket: ^UDP_Socket, data: []byte, address: Net_Address) -> (int, Error) {
	if socket == nil || socket.closed || i64(socket.socket) == 0 {
		return 0, .Invalid_Handle
	}
	if len(data) == 0 {
		return 0, .None
	}
	if address.Port <= 0 || address.Port > 65535 {
		return 0, .Invalid_Data
	}
	endpoint, resolve_err := _net_to_endpoint(address)
	if resolve_err != .None {
		return 0, resolve_err
	}
	written, send_err := net.send_udp(socket.socket, data, endpoint)
	if send_err != nil {
		if send_err == .Would_Block || send_err == .Timeout {
			return written, .Not_Ready
		}
		return written, _net_map_error(send_err)
	}
	return written, .None
}

// UDP_Receive_From fills `data` with one datagram, returning bytes read
// plus the sender. `(0, Net_Address{}, .Not_Ready)` = nothing waiting.
// The returned `from.Host` is caller-owned: free with `delete()`.
UDP_Receive_From :: proc(socket: ^UDP_Socket, data: []byte) -> (int, Net_Address, Error) {
	if socket == nil || socket.closed || i64(socket.socket) == 0 {
		return 0, {}, .Invalid_Handle
	}
	if len(data) == 0 {
		return 0, {}, .Invalid_Data
	}
	read, remote, recv_err := net.recv_udp(socket.socket, data)
	if recv_err != nil {
		if recv_err == .Would_Block || recv_err == .Timeout {
			return 0, {}, .Not_Ready
		}
		return read, {}, _net_map_error(recv_err)
	}
	return read, _net_endpoint_to_address(remote), .None
}

// UDP_Close shuts a UDP socket down. Nil-safe and idempotent.
UDP_Close :: proc(socket: ^UDP_Socket) {
	if socket == nil || socket.closed {
		return
	}
	socket.closed = true
	if i64(socket.socket) != 0 {
		net.close(socket.socket)
		socket.socket = 0
	}
}

// _net_to_endpoint parses/resolves a Net_Address to a core:net endpoint.
// IP literals take a parse fast-path (no DNS); hostnames go through the
// OS resolver. Port 0 is allowed (ephemeral bind); callers needing a dial
// target reject it themselves.
_net_to_endpoint :: proc(address: Net_Address) -> (net.Endpoint, Error) {
	if len(address.Host) == 0 || address.Port < 0 || address.Port > 65535 {
		return {}, .Invalid_Data
	}
	if addr4, ok := net.parse_ip4_address(address.Host); ok {
		return net.Endpoint{address = addr4, port = address.Port}, .None
	}
	if addr6, ok := net.parse_ip6_address(address.Host); ok {
		return net.Endpoint{address = addr6, port = address.Port}, .None
	}
	ep4, ep6, resolve_err := net.resolve(address.Host)
	if resolve_err != nil {
		return {}, .Invalid_Data
	}
	endpoint := ep4 if ep4.address != nil else ep6
	if endpoint.address == nil {
		return {}, .Invalid_Data
	}
	endpoint.port = address.Port
	return endpoint, .None
}

// _net_endpoint_to_address renders a core:net endpoint as a Net_Address.
// Host is cloned: caller-owned, free with delete().
_net_endpoint_to_address :: proc(endpoint: net.Endpoint) -> Net_Address {
	host := net.address_to_string(endpoint.address)
	cloned, _ := strings.clone(host)
	return Net_Address{Host = cloned, Port = endpoint.port}
}

// _net_map_error folds core:net errors onto thor2d.Error. Would-block style
// outcomes map to .Not_Ready (poll again), bad input to .Invalid_Data,
// permission-gated binds to .Capability_Unavailable, and refused/reset/
// unreachable/unavailable resources to .Resource_Load_Failed.
_net_map_error :: proc(err: net.Network_Error) -> Error {
	if err == nil {
		return .None
	}
	#partial switch e in err {
	case net.Create_Socket_Error:		#partial switch e {
		case .Invalid_Argument:
			return .Invalid_Data
		case .Insufficient_Permissions:
			return .Capability_Unavailable
		case:
			return .Resource_Load_Failed
		}
	case net.Dial_Error:
		#partial switch e {
		case .Invalid_Argument, .Port_Required:
			return .Invalid_Data
		case:
			return .Resource_Load_Failed
		}
	case net.Listen_Error:
		#partial switch e {
		case .Invalid_Argument:
			return .Invalid_Data
		case:
			return .Resource_Load_Failed
		}
	case net.Accept_Error:
		#partial switch e {
		case .Would_Block, .Timeout:
			return .Not_Ready
		case .Invalid_Argument:
			return .Invalid_Data
		case:
			return .Resource_Load_Failed
		}
	case net.Bind_Error:
		#partial switch e {
		case .Invalid_Argument:
			return .Invalid_Data
		case .Insufficient_Permissions_For_Address:
			return .Capability_Unavailable
		case:
			return .Resource_Load_Failed
		}
	case net.TCP_Send_Error:
		#partial switch e {
		case .Would_Block, .Timeout:
			return .Not_Ready
		case .Invalid_Argument:
			return .Invalid_Data
		case:
			return .Resource_Load_Failed
		}
	case net.UDP_Send_Error:
		#partial switch e {
		case .Would_Block, .Timeout:
			return .Not_Ready
		case .Invalid_Argument:
			return .Invalid_Data
		case:
			return .Resource_Load_Failed
		}
	case net.TCP_Recv_Error:
		#partial switch e {
		case .Would_Block, .Timeout:
			return .Not_Ready
		case .Invalid_Argument:
			return .Invalid_Data
		case:
			return .Resource_Load_Failed
		}
	case net.UDP_Recv_Error:
		#partial switch e {
		case .Would_Block, .Timeout:
			return .Not_Ready
		case .Invalid_Argument:
			return .Invalid_Data
		case:
			return .Resource_Load_Failed
		}
	case net.Resolve_Error, net.DNS_Error, net.Parse_Endpoint_Error:
		return .Invalid_Data
	case:
		return .Resource_Load_Failed
	}
}
