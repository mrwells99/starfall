"""A --world server plus a client that walks in through the World button."""
import pathlib, subprocess, sys, time

ROOT = pathlib.Path(__file__).resolve().parents[1]
server = subprocess.Popen(
    ["godot", "--headless", "--path", str(ROOT), "--", "--dedicated", "--world", "--port=27842"],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
client = None
try:
    time.sleep(2.0)
    client = subprocess.Popen(
        ["godot", "--headless", "--path", str(ROOT), "--script", "tests/world_client.gd"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out, _ = client.communicate(timeout=45)
    print("--- CLIENT ---\n%s" % out)
    server.terminate()
    try:
        srv, _ = server.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        server.kill(); srv, _ = server.communicate()
    print("--- SERVER ---\n%s" % srv)
    if client.returncode or "WORLD CLIENT IN" not in out:
        print("The world never admitted the client")
        sys.exit(1)
    if "ERROR:" in out + srv:
        sys.exit(1)
finally:
    for p in (server, client):
        if p is not None and p.poll() is None:
            p.terminate(); p.wait(timeout=5)
