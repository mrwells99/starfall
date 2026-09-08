"""Launch a --dedicated server plus two clients; verify version handshake and auto-start."""
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
server_cmd = ["godot", "--headless", "--path", str(ROOT), "--",
              "--dedicated", "--mode=team", "--min-players=2", "--rematch-delay=2"]
client_cmd = ["godot", "--headless", "--path", str(ROOT),
              "--script", "tests/dedicated_client.gd", "--", "--champion=Ember"]

server = subprocess.Popen(server_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
clients = []
late = None
try:
    time.sleep(1.5)
    for _ in range(2):
        clients.append(subprocess.Popen(client_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
    # A queue must accept someone who arrives while a round is already running
    # and put them in the next one. Before this was fixed, register_player
    # rejected any client whose connection landed mid-round — which, on a server
    # that auto-rematches, is nearly always.
    time.sleep(6)
    late = subprocess.Popen(client_cmd + ["--queued-only"], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)

    for i, c in enumerate(clients):
        out, _ = c.communicate(timeout=45)
        print("--- CLIENT %d ---\n%s" % (i, out))
        if c.returncode or "ERROR:" in out or "DEDICATED CLIENT PASS" not in out:
            print("client %d did not reach a round" % i)
            sys.exit(1)
    late_out, _ = late.communicate(timeout=60)
    print("--- LATE JOINER ---\n%s" % late_out)
    if late.returncode or "DEDICATED CLIENT QUEUED" not in late_out:
        print("A client that arrived mid-round was not queued")
        sys.exit(1)
    server.terminate()
    try:
        server_out, _ = server.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        server.kill()
        server_out, _ = server.communicate()
    print("--- SERVER ---\n%s" % server_out)
    if "DEDICATED READY" not in server_out:
        print("Server did not report READY")
        sys.exit(1)
    if "DEDICATED ROUND START" not in server_out:
        print("Server did not auto-start a round")
        sys.exit(1)
    if "ERROR:" in server_out:
        sys.exit(1)
finally:
    for p in [server, late] + clients:
        if p is not None and p.poll() is None:
            p.terminate()
            p.wait(timeout=5)
