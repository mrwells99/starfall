"""Reject version/schema mismatches and legacy servers before any scene RPC."""
import os
import pathlib
import re
import shutil
import subprocess
import tempfile
import threading

ROOT = pathlib.Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", "godot")
with tempfile.TemporaryDirectory(prefix="starfall-handshake-") as directory:
    base = pathlib.Path(directory)
    for scenario in ("version", "schema", "protocol", "legacy"):
        fixture = base / scenario
        fixture.mkdir()
        for item in ROOT.iterdir():
            if item.name in {".git", ".codex", ".agents"}:
                continue
            if item.name == "scripts":
                shutil.copytree(item, fixture / item.name)
            elif os.name == "nt" and item.is_dir():
                # Directory junctions need no symbolic-link privilege on Windows.
                destination = str(fixture / item.name).replace("'", "''")
                target = str(item).replace("'", "''")
                subprocess.run(["powershell", "-NoProfile", "-Command", f"New-Item -ItemType Junction -Path '{destination}' -Target '{target}' | Out-Null"], check=True, capture_output=True)
            elif os.name == "nt":
                os.link(item, fixture / item.name)
            else:
                (fixture / item.name).symlink_to(item, target_is_directory=item.is_dir())
        config = fixture / "scripts/config.gd"
        script = fixture / "scripts/arena.gd"
        if scenario == "version":
            config.write_text(re.sub(r'const VERSION := "[^"]+"', 'const VERSION := "0.0.0"', config.read_text()))
        elif scenario == "schema":
            script.write_text(script.read_text() + '\n@rpc("authority", "call_remote", "reliable")\nfunc aaa_incompatible_test_rpc() -> void:\n\tpass\n')
        elif scenario == "protocol":
            handshake = fixture / "scripts/network_handshake.gd"
            handshake.write_text(handshake.read_text().replace("const PROTOCOL := 2", "const PROTOCOL := 1"))
        else:
            script.write_text(script.read_text().replace('\tnetwork_handshake.setup(self)\n', ''))
        env = dict(os.environ, XDG_DATA_HOME=str(base / "userdata"))
        server = subprocess.Popen([GODOT, "--headless", "--path", str(fixture), "--log-file", str(base / f"{scenario}-server.log"), "--", "--dedicated", "--world", "--port=27943"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", env=env)
        server_lines = []
        server_ready = threading.Event()
        def read_server():
            for line in server.stdout:
                server_lines.append(line)
                if "DEDICATED READY" in line:
                    server_ready.set()
        reader = threading.Thread(target=read_server, daemon=True)
        reader.start()
        try:
            assert server_ready.wait(timeout=30), "Compatibility fixture did not report server readiness"
            client = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--log-file", str(base / f"{scenario}-client.log"), "--script", "tests/handshake_client.gd"], capture_output=True, text=True, encoding="utf-8", errors="replace", env=env, timeout=18)
            print(scenario, client.stdout, client.stderr)
            assert client.returncode == 0 and "HANDSHAKE REJECTION PASS" in client.stdout
            assert "ERROR:" not in client.stdout + client.stderr
        finally:
            if os.name == "nt":
                # The Windows console launcher owns a child engine process.
                subprocess.run(["taskkill", "/PID", str(server.pid), "/T", "/F"], capture_output=True, timeout=5)
            else:
                server.terminate()
            server.wait(timeout=5)
            reader.join(timeout=2)
            output = "".join(server_lines)
            print(output)
            assert "ERROR:" not in output
