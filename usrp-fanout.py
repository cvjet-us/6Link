#!/usr/bin/env python3
import socket, select, sys
LOOPBACK = "127.0.0.1"
ROUTES = [
    (34001, [32002, 32003, 32004, 32170, 32006]),
    (34002, [32001, 32003, 32004, 32170, 32006]),
    (34003, [32001, 32002, 32004, 32170, 32006]),
    (34004, [32001, 32002, 32003, 32170, 32006]),
    (34170, [32001, 32002, 32003, 32004, 32006]),
    (34006, [32001, 32002, 32003, 32004, 32170]),
]
def main():
    listeners = {}
    sender = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    for lp, dests in ROUTES:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((LOOPBACK, lp))
        listeners[s] = dests
        print(f"[fanout] {LOOPBACK}:{lp} -> {dests}", flush=True)
    try:
        while True:
            ready, _, _ = select.select(list(listeners.keys()), [], [])
            for s in ready:
                data, _ = s.recvfrom(4096)
                for port in listeners[s]:
                    sender.sendto(data, (LOOPBACK, port))
    except KeyboardInterrupt:
        return 0
if __name__ == "__main__":
    sys.exit(main())
