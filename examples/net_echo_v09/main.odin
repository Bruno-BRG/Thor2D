package net_echo_v09

// Thor2D v0.9 network echo demo: spins a TCP listener on 127.0.0.1:17421,
// connects a client, sends "ping", echoes it back through the accepted
// server stream, prints the transcript and quits. Imports ONLY thor2d
// (plus core libs, which parity-check allows). Pure CLI: no window, no
// Context, runs headless via `odin run examples/net_echo_v09`.

import "core:fmt"
import "core:os"
import "core:time"
import thor2d "thor2d:thor2d"

ECHO_PORT :: 17421
ECHO_STEP_TIMEOUT :: 5 * time.Second
ECHO_POLL_SLEEP :: 5 * time.Millisecond

fail :: proc(message: string, err: thor2d.Error) -> ! {
	fmt.printf("net_echo: %s: %s\n", message, thor2d.Error_String(err))
	os.exit(1)
}

main :: proc() {
	address := thor2d.Net_Address{Host = "127.0.0.1", Port = ECHO_PORT}

	listener, listen_err := thor2d.TCP_Listen(address)
	if listen_err != .None {
		fail("listen failed", listen_err)
	}
	defer thor2d.TCP_Close(&listener)
	fmt.printf("net_echo: listening on %s:%d\n", address.Host, address.Port)

	client, connect_err := thor2d.TCP_Connect(address)
	if connect_err != .None {
		fail("connect failed", connect_err)
	}
	defer thor2d.TCP_Close(&client)
	fmt.println("net_echo: connected")

	server := thor2d.TCP_Stream{}
	accept_start := time.tick_now()
	for {
		peer, accept_err := thor2d.TCP_Accept(&listener)
		if accept_err == .None {
			server = peer
			break
		}
		if accept_err != .Not_Ready {
			fail("accept failed", accept_err)
		}
		if time.tick_since(accept_start) > ECHO_STEP_TIMEOUT {
			fail("accept timed out", .Not_Ready)
		}
		time.sleep(ECHO_POLL_SLEEP)
	}
	defer thor2d.TCP_Close(&server)
	fmt.println("net_echo: accepted")

	sent, send_err := thor2d.TCP_Send(&client, transmute([]byte)string("ping"))
	if send_err != .None {
		fail("client send failed", send_err)
	}
	fmt.printf("net_echo: client sent %d bytes\n", sent)

	server_buf := make([]byte, 64)
	defer delete(server_buf)
	got := 0
	recv_start := time.tick_now()
	for {
		n, recv_err := thor2d.TCP_Receive(&server, server_buf)
		if recv_err == .None {
			if n == 0 {
				fail("server saw graceful close mid-echo", .Invalid_Handle)
			}
			got = n
			break
		}
		if recv_err != .Not_Ready {
			fail("server receive failed", recv_err)
		}
		if time.tick_since(recv_start) > ECHO_STEP_TIMEOUT {
			fail("server receive timed out", .Not_Ready)
		}
		time.sleep(ECHO_POLL_SLEEP)
	}
	fmt.printf("net_echo: server received \"%s\"\n", string(server_buf[:got]))

	echoed, echo_err := thor2d.TCP_Send(&server, server_buf[:got])
	if echo_err != .None {
		fail("server echo failed", echo_err)
	}
	fmt.printf("net_echo: server echoed %d bytes\n", echoed)

	client_buf := make([]byte, 64)
	defer delete(client_buf)
	back := 0
	echo_start := time.tick_now()
	for {
		n, recv_err := thor2d.TCP_Receive(&client, client_buf)
		if recv_err == .None {
			if n == 0 {
				fail("client saw graceful close mid-echo", .Invalid_Handle)
			}
			back = n
			break
		}
		if recv_err != .Not_Ready {
			fail("client receive failed", recv_err)
		}
		if time.tick_since(echo_start) > ECHO_STEP_TIMEOUT {
			fail("client receive timed out", .Not_Ready)
		}
		time.sleep(ECHO_POLL_SLEEP)
	}
	reply := string(client_buf[:back])
	fmt.printf("net_echo: client received \"%s\"\n", reply)
	if reply != "ping" {
		fail("echo mismatch", .Invalid_Data)
	}
	fmt.println("net_echo: OK")
}
