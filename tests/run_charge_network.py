"""Exercise authoritative Charge and client prediction over real ENet."""
import os
from pathlib import Path
import subprocess
import sys
import threading

root = Path(__file__).resolve().parents[1]
base = [os.environ.get("GODOT", "godot"), "--headless", "--path", str(root),
        "--script", "tests/charge_network_peer.gd", "--", *sys.argv[1:]]
host = subprocess.Popen(base + ["--test-host"], stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
ready = threading.Event()
lines = []


def read_host():
    for line in host.stdout:
        lines.append(line)
        if "CHARGE NETWORK READY" in line:
            ready.set()


reader = threading.Thread(target=read_host, daemon=True)
reader.start()
client = None
try:
    if not ready.wait(30):
        raise RuntimeError("Charge test host did not start")
    client = subprocess.Popen(base, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, encoding="utf-8", errors="replace")
    output, _ = client.communicate(timeout=30)
    host.wait(timeout=30)
    reader.join(timeout=2)
    host_output = "".join(lines)
    print(host_output + output)
    sys.exit(1 if host.returncode or client.returncode or "ERROR:" in host_output + output
             or "HOST PASS" not in host_output or "CLIENT PASS" not in output else 0)
finally:
    for process in (host, client):
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
