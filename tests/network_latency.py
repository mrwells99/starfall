"""Bounded localhost UDP relay: delay ENet data and ACKs, so its RTT is real."""
import heapq
import random
import select
import socket
import threading
import time


class LatencyRelay:
    def __init__(self, listen_port, server_port, round_trip_ms, *, jitter_ms=0, loss_percent=0, seed=0):
        if round_trip_ms < 0 or jitter_ms < 0 or not 0 <= loss_percent <= 100:
            raise ValueError('Invalid relay delay, jitter, or loss')
        self.server = ('127.0.0.1', server_port)
        self.delay = round_trip_ms / 2000.0
        self.jitter = jitter_ms / 1000.0  # +/- variation on each one-way packet
        self.loss = loss_percent / 100.0
        self.random = random.Random(seed)
        self.received = 0
        self.dropped = 0
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.bind(('127.0.0.1', listen_port))
        self.socket.setblocking(False)
        self.stop = threading.Event()
        self.error = None
        self.thread = threading.Thread(target=self.run, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def run(self):
        pending, client = [], None
        try:
            while not self.stop.is_set():
                now = time.monotonic()
                while pending and pending[0][0] <= now:
                    _, packet, destination = heapq.heappop(pending)
                    self.socket.sendto(packet, destination)
                timeout = min(.01, max(0, pending[0][0] - now)) if pending else .01
                if select.select([self.socket], [], [], timeout)[0]:
                    try:
                        packet, source = self.socket.recvfrom(65535)
                    except ConnectionResetError:
                        # Windows reports a late UDP packet to an exited peer as ICMP.
                        continue
                    if source == self.server:
                        destination = client
                    else:
                        if client is not None and source != client:
                            continue
                        client, destination = source, self.server
                    if destination is not None:
                        self.received += 1
                        if self.loss and self.random.random() < self.loss:
                            self.dropped += 1
                            continue
                        if len(pending) >= 4096:
                            raise RuntimeError('Test relay exceeded its packet queue bound')
                        delay = self.delay
                        if self.jitter:
                            delay = max(0, delay + self.random.uniform(-self.jitter, self.jitter))
                        heapq.heappush(pending, (time.monotonic() + delay, packet, destination))
        except Exception as error:
            self.error = error

    def __exit__(self, *_):
        self.stop.set()
        self.thread.join(timeout=2)
        self.socket.close()
        if self.error:
            raise self.error
