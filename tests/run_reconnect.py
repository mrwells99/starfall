"""Real ENet reconnect with invalid-ticket rejection and preserved actor state."""
import os
import pathlib
import subprocess
import threading

root = pathlib.Path(__file__).resolve().parents[1]
command = [os.environ.get("GODOT", "godot"), "--headless", "--path", str(root), "--script", "tests/reconnect_peer.gd", "--"]
host = subprocess.Popen(command + ["--host"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
lines = []
ready = threading.Event()
def read():
    for line in host.stdout:
        lines.append(line)
        if "RECONNECT HOST READY" in line:
            ready.set()
reader = threading.Thread(target=read, daemon=True)
reader.start()
client = None
try:
    if not ready.wait(20):
        raise RuntimeError("Reconnect host did not start: " + "".join(lines))
    client = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    output, _ = client.communicate(timeout=25)
    host.wait(timeout=25)
    reader.join(timeout=2)
    host_output = "".join(lines)
    print(host_output + output)
    if host.returncode or client.returncode or "ERROR:" in host_output + output or "RECONNECT HOST PASS" not in host_output or "RECONNECT CLIENT PASS" not in output:
        raise SystemExit(1)
finally:
    for process in [host, client]:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
