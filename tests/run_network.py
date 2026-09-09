"""Launch real host/client processes; test localhost ENet with optional delay."""
import os
import pathlib
import subprocess
import sys
import threading

ROOT = pathlib.Path(__file__).resolve().parents[1]
flags = sys.argv[1:]
base = [os.environ.get("GODOT", "godot"), "--headless", "--path", str(ROOT), "--script", "tests/network_peer.gd", "--"]
host = subprocess.Popen(base + ["--test-host"] + flags, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
host_lines = []
host_ready = threading.Event()

def read_host():
    for line in host.stdout:
        host_lines.append(line)
        if "NETWORK TEST HOST READY" in line:
            host_ready.set()

host_reader = threading.Thread(target=read_host, daemon=True)
host_reader.start()
client = None
try:
    # Asset loading varies by machine; a fixed startup sleep can make the client
    # connect before ENet is listening and turn a valid run into a menu timeout.
    if not host_ready.wait(timeout=30):
        print("HOST\n" + "".join(host_lines))
        raise RuntimeError("Network fixture did not report host readiness")
    client = subprocess.Popen(base + flags, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
    client_output, _ = client.communicate(timeout=30)
    host.wait(timeout=30)
    host_reader.join(timeout=2)
    host_output = "".join(host_lines)
    print("HOST\n" + host_output + "CLIENT\n" + client_output)
    if (host.returncode or client.returncode or "ERROR:" in host_output + client_output
            or "NETWORK HOST PASS:" not in host_output or "NETWORK CLIENT PASS:" not in client_output):
        sys.exit(1)
finally:
    for proc in (host, client):
        if proc is not None and proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=5)
