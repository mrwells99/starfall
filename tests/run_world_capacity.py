"""Verify ten simultaneous World players, overflow rejection, and slot reuse."""
import pathlib
import os
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = ["godot", "--headless", "--path", str(ROOT)]
processes = []


def launch(folder, name, args):
    path = pathlib.Path(folder) / f"{name}.log"
    with path.open("w") as log:
        env = dict(os.environ, XDG_DATA_HOME=str(pathlib.Path(folder) / name))
        process = subprocess.Popen(BASE + args, stdout=log, stderr=subprocess.STDOUT, env=env)
    processes.append(process)
    return process, path


def wait_for(process, path, marker, timeout=45):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        output = path.read_text()
        if "ERROR:" in output:
            raise AssertionError(output)
        if marker in output:
            return
        if process.poll() is not None:
            raise AssertionError(f"Process exited before {marker}: {output}")
        time.sleep(0.1)
    raise AssertionError(f"Timed out waiting for {marker}: {path.read_text()}")


with tempfile.TemporaryDirectory(prefix="starfall-world-capacity-") as folder:
    try:
        server, server_log = launch(folder, "server", ["--", "--dedicated", "--world", "--port=27842"])
        wait_for(server, server_log, "DEDICATED READY")
        clients = []
        args = ["--script", "tests/world_client.gd", "--", "--test-hold"]
        for index in range(10):
            client, log = launch(folder, f"client-{index + 1}", args)
            wait_for(client, log, "WORLD CLIENT IN")
            clients.append((client, log))
            assert all(p.poll() is None for p, _ in clients)
            print(f"World player {index + 1}/10 admitted", flush=True)

        overflow, log = launch(folder, "overflow", args)
        overflow.wait(timeout=45)
        assert overflow.returncode != 0 and "WORLD CLIENT IN" not in log.read_text(), log.read_text()
        assert "World client stuck:" in log.read_text(), log.read_text()
        assert all(p.poll() is None for p, _ in clients)
        print("11th player blocked while all ten remain connected", flush=True)

        clients[0][0].terminate()
        clients[0][0].wait(timeout=5)
        # Allow ENet to observe the departed peer before reusing its slot.
        time.sleep(4)
        replacement, replacement_log = launch(folder, "replacement", args)
        wait_for(replacement, replacement_log, "WORLD CLIENT IN")
        for _, path in clients + [(server, server_log), (replacement, replacement_log)]:
            assert "ERROR:" not in path.read_text(), path.read_text()
        print("Freed slot accepts a replacement player; World capacity checks passed", flush=True)
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for process in processes:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
