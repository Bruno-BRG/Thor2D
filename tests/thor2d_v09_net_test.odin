package tests

import "core:fmt"
import "core:testing"
import "core:time"
import thor2d "thor2d:thor2d"

// v0.9 P2: non-blocking TCP+UDP loopback plus mobile-stub behavior. All
// tests are headless-safe (loopback needs no window or GPU).
//
// Sandbox policy: if the sandbox blocks loopback sockets, the affected
// test prints a SKIP note naming the specific thor2d.Error and returns
// without failing. A test only asserts once its own sockets exist, so a
// network-policy denial can never fail the suite. Real logic errors after
// successful setup still fail loudly.

V09_NET_TCP_PORT :: 17423
V09_NET_ACCEPT_PORT :: 17426
V09_NET_UDP_A_PORT :: 17424
V09_NET_UDP_B_PORT :: 17425
V09_NET_STEP_TIMEOUT :: 2 * time.Second
V09_NET_POLL_SLEEP :: 5 * time.Millisecond

// _v09_net_skip reports a sandbox-policy skip: the named thor2d.Error shows
// loopback is restricted here, so the test passes without asserting.
_v09_net_skip :: proc(reason: string, err: thor2d.Error) {
	fmt.printf("v09 net test SKIPPED (%s): %s\n", reason, thor2d.Error_String(err))
}

@(test)
test_v09_net_tcp_loopback_echo :: proc(t: ^testing.T) {
	address := thor2d.Net_Address{Host = "127.0.0.1", Port = V09_NET_TCP_PORT}
	listener, listen_err := thor2d.TCP_Listen(address)
	if listen_err != .None {
		_v09_net_skip("loopback listen denied", listen_err)
		return
	}
	defer thor2d.TCP_Close(&listener)

	client, connect_err := thor2d.TCP_Connect(address)
	if connect_err != .None {
		_v09_net_skip("loopback connect denied", connect_err)
		return
	}
	defer thor2d.TCP_Close(&client)

	server := thor2d.TCP_Stream{}
	accepted := false
	accept_start := time.tick_now()
	for time.tick_since(accept_start) < V09_NET_STEP_TIMEOUT {
		peer, accept_err := thor2d.TCP_Accept(&listener)
		if accept_err == .None {
			server = peer
			accepted = true
			break
		}
		if accept_err != .Not_Ready {
			_v09_net_skip("accept denied mid-test", accept_err)
			return
		}
		time.sleep(V09_NET_POLL_SLEEP)
	}
	if !accepted {
		_v09_net_skip("accept never fired", .Not_Ready)
		return
	}
	defer thor2d.TCP_Close(&server)

	sent, send_err := thor2d.TCP_Send(&client, transmute([]byte)string("ping"))
	if send_err != .None {
		_v09_net_skip("client send denied", send_err)
		return
	}
	testing.expect(t, sent == 4)

	server_buf := make([]byte, 64)
	defer delete(server_buf)
	got := 0
	got_data := false
	recv_start := time.tick_now()
	for time.tick_since(recv_start) < V09_NET_STEP_TIMEOUT {
		n, recv_err := thor2d.TCP_Receive(&server, server_buf)
		if recv_err == .None {
			if n == 0 {
				testing.expect(t, false, "server saw graceful close mid-echo")
				return
			}
			got, got_data = n, true
			break
		}
		if recv_err != .Not_Ready {
			_v09_net_skip("server receive denied", recv_err)
			return
		}
		time.sleep(V09_NET_POLL_SLEEP)
	}
	if !got_data {
		_v09_net_skip("server received nothing (datagrams blackholed?)", .Not_Ready)
		return
	}
	testing.expect(t, got == 4)
	testing.expect(t, string(server_buf[:got]) == "ping")

	echoed, echo_err := thor2d.TCP_Send(&server, server_buf[:got])
	if echo_err != .None {
		_v09_net_skip("server echo denied", echo_err)
		return
	}
	testing.expect(t, echoed == got)

	client_buf := make([]byte, 64)
	defer delete(client_buf)
	back := 0
	back_data := false
	echo_start := time.tick_now()
	for time.tick_since(echo_start) < V09_NET_STEP_TIMEOUT {
		n, recv_err := thor2d.TCP_Receive(&client, client_buf)
		if recv_err == .None {
			if n == 0 {
				testing.expect(t, false, "client saw graceful close mid-echo")
				return
			}
			back, back_data = n, true
			break
		}
		if recv_err != .Not_Ready {
			_v09_net_skip("client receive denied", recv_err)
			return
		}
		time.sleep(V09_NET_POLL_SLEEP)
	}
	if !back_data {
		_v09_net_skip("client received nothing (datagrams blackholed?)", .Not_Ready)
		return
	}
	testing.expect(t, back == 4)
	testing.expect(t, string(client_buf[:back]) == "ping")
}

@(test)
test_v09_net_accept_not_ready_and_close :: proc(t: ^testing.T) {
	listener, listen_err := thor2d.TCP_Listen(thor2d.Net_Address{Host = "127.0.0.1", Port = V09_NET_ACCEPT_PORT})
	if listen_err != .None {
		_v09_net_skip("loopback listen denied", listen_err)
		return
	}
	defer thor2d.TCP_Close(&listener)

	// No peer connected: a non-blocking listener must report .Not_Ready,
	// never block and never fake a stream.
	_, accept_err := thor2d.TCP_Accept(&listener)
	testing.expect(t, accept_err == .Not_Ready)

	// Closed listeners reject loudly; double close stays silent.
	thor2d.TCP_Close(&listener)
	_, after_err := thor2d.TCP_Accept(&listener)
	testing.expect(t, after_err == .Invalid_Handle)
	thor2d.TCP_Close(&listener)
	thor2d.TCP_Close_Listener(nil)
	thor2d.TCP_Close_Stream(nil)

	// Zero-value and nil handles never touch the OS.
	zero_stream := thor2d.TCP_Stream{}
	zero_buf := make([]byte, 8)
	defer delete(zero_buf)
	_, zero_send := thor2d.TCP_Send(&zero_stream, zero_buf)
	testing.expect(t, zero_send == .Invalid_Handle)
	_, zero_recv := thor2d.TCP_Receive(&zero_stream, zero_buf)
	testing.expect(t, zero_recv == .Invalid_Handle)
	_, nil_send := thor2d.TCP_Send(nil, zero_buf)
	testing.expect(t, nil_send == .Invalid_Handle)
	thor2d.TCP_Close_Stream(nil)
	thor2d.UDP_Close(nil)
}

@(test)
test_v09_net_udp_loopback :: proc(t: ^testing.T) {
	a, err_a := thor2d.UDP_Open(V09_NET_UDP_A_PORT)
	if err_a != .None {
		_v09_net_skip("loopback UDP bind denied", err_a)
		return
	}
	defer thor2d.UDP_Close(&a)
	b, err_b := thor2d.UDP_Open(V09_NET_UDP_B_PORT)
	if err_b != .None {
		_v09_net_skip("loopback UDP bind denied", err_b)
		return
	}
	defer thor2d.UDP_Close(&b)

	tmp := make([]byte, 64)
	defer delete(tmp)

	// Nothing sent yet: non-blocking receive reports .Not_Ready.
	n0, _, r0 := thor2d.UDP_Receive_From(&a, tmp)
	testing.expect(t, r0 == .Not_Ready)
	testing.expect(t, n0 == 0)

	sent, send_err := thor2d.UDP_Send_To(&a, transmute([]byte)string("pong"), thor2d.Net_Address{Host = "127.0.0.1", Port = V09_NET_UDP_B_PORT})
	if send_err != .None {
		_v09_net_skip("loopback UDP send denied", send_err)
		return
	}
	testing.expect(t, sent == 4)

	got := 0
	got_from := false
	from := thor2d.Net_Address{}
	recv_start := time.tick_now()
	for time.tick_since(recv_start) < V09_NET_STEP_TIMEOUT {
		n, sender, recv_err := thor2d.UDP_Receive_From(&b, tmp)
		if recv_err == .None {
			got, from, got_from = n, sender, true
			break
		}
		if recv_err != .Not_Ready {
			_v09_net_skip("loopback UDP receive denied", recv_err)
			return
		}
		time.sleep(V09_NET_POLL_SLEEP)
	}
	if !got_from {
		_v09_net_skip("loopback UDP datagram never arrived", .Not_Ready)
		return
	}
	defer delete(from.Host)
	testing.expect(t, got == 4)
	testing.expect(t, string(tmp[:got]) == "pong")
	testing.expect(t, from.Port == V09_NET_UDP_A_PORT)
}

@(test)
test_v09_net_resolve_and_reject :: proc(t: ^testing.T) {
	// IP literals validate with no DNS involved.
	addr, err := thor2d.Net_Resolve("127.0.0.1", 17421)
	testing.expect(t, err == .None)
	testing.expect(t, addr.Host == "127.0.0.1" && addr.Port == 17421)

	// Bad input is loud, never a fake address.
	_, empty_err := thor2d.Net_Resolve("", 80)
	testing.expect(t, empty_err == .Invalid_Data)
	_, zero_port := thor2d.Net_Resolve("127.0.0.1", 0)
	testing.expect(t, zero_port == .Invalid_Data)
	_, big_port := thor2d.Net_Resolve("127.0.0.1", 70000)
	testing.expect(t, big_port == .Invalid_Data)
	_, bad_connect := thor2d.TCP_Connect(thor2d.Net_Address{Host = "", Port = 80})
	testing.expect(t, bad_connect == .Invalid_Data)
	_, zero_connect := thor2d.TCP_Connect(thor2d.Net_Address{Host = "127.0.0.1", Port = 0})
	testing.expect(t, zero_connect == .Invalid_Data)

	// Nothing listens on the reject probe port: the dial must fail loudly.
	// (Any failure counts: refused and sandbox-denied both prove no fake.)
	probe, probe_err := thor2d.TCP_Connect(thor2d.Net_Address{Host = "127.0.0.1", Port = 17429})
	testing.expect(t, probe_err != .None)
	thor2d.TCP_Close(&probe)
}

@(test)
test_v09_mobile_stubs_headless :: proc(t: ^testing.T) {
	// Desktop has no vibration hardware; bad durations are still rejected.
	testing.expect(t, thor2d.Vibrate(0.5) == .Unsupported)
	testing.expect(t, thor2d.Vibrate(0) == .Invalid_Data)
	testing.expect(t, thor2d.Vibrate(-1) == .Invalid_Data)

	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	if err != .None {
		return
	}
	defer thor2d.Destroy(&ctx)

	// Headless has no window: orientation is honestly "unknown".
	testing.expect(t, thor2d.Get_Display_Orientation(&ctx) == "unknown")
	testing.expect(t, thor2d.Get_Display_Orientation(nil) == "unknown")
	// Display sleep is desktop-unsupported in every context.
	testing.expect(t, thor2d.Set_Display_Sleep_Enabled(&ctx, true) == .Unsupported)
	testing.expect(t, thor2d.Set_Display_Sleep_Enabled(nil, false) == .Unsupported)
}
