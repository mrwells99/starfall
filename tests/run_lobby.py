"""Private lobbies: claim a pool slot, hand out a code, and join by code.

Runs two lobby server processes. The first host takes port 27850; the second must
probe past it to 27851. The joiner is given the *second* code, so it has to walk
past a claimed-but-wrong lobby before it finds its match.
"""
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
PORTS = [27850, 27851]

def server(port):
    return subprocess.Popen(
        ["godot", "--headless", "--path", str(ROOT), "--",
         "--dedicated", "--lobby", "--port=%d" % port, "--rematch-delay=2"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

def client(*args):
    return subprocess.Popen(
        ["godot", "--headless", "--path", str(ROOT), "--script", "tests/lobby_client.gd", "--"] + list(args),
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

def read_code(proc, label, timeout=30):
    """Block until the client prints the code its server assigned."""
    deadline = time.time() + timeout
    lines = []
    while time.time() < deadline:
        line = proc.stdout.readline()
        if not line:
            break
        lines.append(line)
        if line.startswith("LOBBY CODE="):
            # "LOBBY CODE=WDEA port=27851"
            fields = dict(f.split("=", 1) for f in line.strip().split() if "=" in f)
            print("%s -> code=%s port=%s" % (label, fields.get("CODE"), fields.get("port")))
            return fields.get("CODE"), lines
    print("--- %s (no code) ---\n%s" % (label, "".join(lines)))
    return None, lines

servers = []
hosts = []
joiner = None
try:
    servers = [server(p) for p in PORTS]
    time.sleep(2.0)

    first = client("--host-lobby", "--hold")
    hosts.append(first)
    code_a, _ = read_code(first, "HOST A")
    if code_a is None:
        print("First host never received a lobby code")
        sys.exit(1)

    second = client("--host-lobby")
    hosts.append(second)
    code_b, head_b = read_code(second, "HOST B")
    if code_b is None:
        print("Second host never received a lobby code (probe past a claimed slot failed)")
        sys.exit(1)
    if code_a == code_b:
        print("Both hosts got the same code %s — they landed on the same slot" % code_a)
        sys.exit(1)

    joiner = client("--join-code=%s" % code_b)
    join_out, _ = joiner.communicate(timeout=60)
    print("--- JOINER (code %s) ---\n%s" % (code_b, join_out))
    rest_b, _ = second.communicate(timeout=60)
    host_b_out = "".join(head_b) + rest_b
    print("--- HOST B (code %s) ---\n%s" % (code_b, host_b_out))

    ok = True
    if joiner.returncode or "LOBBY CLIENT PASS" not in join_out:
        print("Joiner did not reach a round via its code")
        ok = False
    if second.returncode or "LOBBY CLIENT PASS" not in host_b_out:
        print("Host B did not reach a round")
        ok = False
    for name, out in (("JOINER", join_out), ("HOST B", host_b_out)):
        if "ERROR:" in out:
            print("%s reported an engine error" % name)
            ok = False
    sys.exit(0 if ok else 1)
finally:
    for p in servers + hosts + ([joiner] if joiner else []):
        if p is not None and p.poll() is None:
            p.terminate()
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                p.kill()
