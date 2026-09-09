"""Launch real host/client processes; test localhost ENet with optional delay."""
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
flags = sys.argv[1:]
base = ["godot", "--headless", "--path", str(ROOT), "--script", "tests/network_peer.gd", "--"]
host = subprocess.Popen(base + ["--test-host"] + flags, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
client = None
try:
    time.sleep(0.8)
    client = subprocess.Popen(base + flags, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    client_output, _ = client.communicate(timeout=30)
    host_output, _ = host.communicate(timeout=30)
    print("HOST\n" + host_output + "CLIENT\n" + client_output)
    if (host.returncode or client.returncode or "ERROR:" in host_output + client_output
            or "NETWORK HOST PASS:" not in host_output or "NETWORK CLIENT PASS:" not in client_output):
        sys.exit(1)
finally:
    for proc in (host, client):
        if proc is not None and proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=5)
