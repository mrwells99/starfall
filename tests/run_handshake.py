"""Reject version/schema mismatches and legacy servers before any scene RPC."""
import os
import pathlib
import re
import shutil
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="starfall-handshake-") as directory:
    base = pathlib.Path(directory)
    for scenario in ("version", "schema", "legacy"):
        fixture = base / scenario
        fixture.mkdir()
        for item in ROOT.iterdir():
            if item.name in {".git", ".codex", ".agents"}:
                continue
            if item.name == "scripts":
                shutil.copytree(item, fixture / item.name)
            else:
                (fixture / item.name).symlink_to(item, target_is_directory=item.is_dir())
        config = fixture / "scripts/config.gd"
        script = fixture / "scripts/arena.gd"
        if scenario == "version":
            config.write_text(re.sub(r'const VERSION := "[^"]+"', 'const VERSION := "0.0.0"', config.read_text()))
        elif scenario == "schema":
            script.write_text(script.read_text() + '\n@rpc("authority", "call_remote", "reliable")\nfunc aaa_incompatible_test_rpc() -> void:\n\tpass\n')
        else:
            script.write_text(script.read_text().replace('\tnetwork_handshake.setup(self)\n', ''))
        env = dict(os.environ, XDG_DATA_HOME=str(base / "userdata"))
        server = subprocess.Popen(["godot", "--headless", "--path", str(fixture), "--log-file", str(base / f"{scenario}-server.log"), "--", "--dedicated", "--world", "--port=27943"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
        try:
            time.sleep(1)
            client = subprocess.run(["godot", "--headless", "--path", str(ROOT), "--log-file", str(base / f"{scenario}-client.log"), "--script", "tests/handshake_client.gd"], capture_output=True, text=True, env=env, timeout=18)
            print(scenario, client.stdout, client.stderr)
            assert client.returncode == 0 and "HANDSHAKE REJECTION PASS" in client.stdout
            assert "ERROR:" not in client.stdout + client.stderr
        finally:
            server.terminate()
            output, _ = server.communicate(timeout=5)
            print(output)
            assert "ERROR:" not in output
