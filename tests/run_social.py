"""Real ENet world challenge/accept, chat, late join and disconnect regression."""
import os
import pathlib
import subprocess
import tempfile
import threading

ROOT = pathlib.Path(__file__).resolve().parents[1]
processes = []
records = []
# Windows may briefly retain a released engine log handle after process exit.
with tempfile.TemporaryDirectory(prefix="starfall-social-", ignore_cleanup_errors=True) as directory:
    def launch(name, args, marker=""):
        env = dict(os.environ, XDG_DATA_HOME=f"{directory}/{name}")
        process = subprocess.Popen([os.environ.get("GODOT", "godot"), "--headless", "--path", str(ROOT), "--log-file", f"{directory}/{name}.log", *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
        processes.append(process)
        lines = []
        ready = threading.Event()
        def read():
            for line in process.stdout:
                lines.append(line)
                if marker and marker in line:
                    ready.set()
        reader = threading.Thread(target=read, daemon=True)
        reader.start()
        records.append((process, lines, reader))
        return process, ready
    try:
        server, ready = launch("server", ["--", "--dedicated", "--world", "--port=27942"], "DEDICATED READY")
        assert ready.wait(30), "Social server did not start"
        observer, ready = launch("observer", ["--script", "tests/social_peer.gd", "--", "--observer"], "SOCIAL PEER READY")
        assert ready.wait(30), "Observer did not enter world"
        guest, _ = launch("guest", ["--script", "tests/social_peer.gd"])
        for process in [guest, observer]:
            process.wait(timeout=30)
            _, lines, reader = next(record for record in records if record[0] is process)
            reader.join(timeout=2)
            output = "".join(lines)
            assert process.returncode == 0 and "PASS" in output and "ERROR:" not in output
        server.terminate()
        server.wait(timeout=5)
        records[0][2].join(timeout=2)
        assert "ERROR:" not in "".join(records[0][1])
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
        for _, lines, reader in records:
            reader.join(timeout=2)
            print("".join(lines))
