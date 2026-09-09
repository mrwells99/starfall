"""Exercise automatic rematch, replicated summary, and departure/waiting UI over ENet."""
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
COMMAND = ["godot", "--headless", "--path", str(ROOT), "--script", "tests/polish_peer.gd", "--"]
processes = []
try:
    processes.append(subprocess.Popen(COMMAND + ["--results-host"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
    time.sleep(1)
    processes.append(subprocess.Popen(COMMAND, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
    processes.append(subprocess.Popen(COMMAND + ["--leaver"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
    for process, marker in zip(processes, ["RESULTS HOST PASS", "RESULTS CLIENT PASS", "RESULTS LEAVER PASS"]):
        output, _ = process.communicate(timeout=30)
        print(output)
        if process.returncode or "ERROR:" in output or marker not in output:
            raise SystemExit(1)
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
