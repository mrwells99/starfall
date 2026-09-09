"""Real ENet world challenge/accept, chat, late join and disconnect regression."""
import os
import pathlib
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
processes = []
with tempfile.TemporaryDirectory(prefix="starfall-social-") as directory:
    def launch(name, args):
        env = dict(os.environ, XDG_DATA_HOME=f"{directory}/{name}")
        process = subprocess.Popen(["godot", "--headless", "--path", str(ROOT), "--log-file", f"{directory}/{name}.log", *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
        processes.append(process)
        return process
    try:
        server = launch("server", ["--", "--dedicated", "--world", "--port=27942"])
        time.sleep(1)
        observer = launch("observer", ["--script", "tests/social_peer.gd", "--", "--observer"])
        time.sleep(2)
        guest = launch("guest", ["--script", "tests/social_peer.gd"])
        for process in [guest, observer]:
            output, _ = process.communicate(timeout=30)
            print(output)
            assert process.returncode == 0 and "PASS" in output and "ERROR:" not in output
        server.terminate()
        output, _ = server.communicate(timeout=5)
        print(output)
        assert "ERROR:" not in output
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
