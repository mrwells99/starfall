"""Exercise one real ENet host and five clients in a full 3v3 round."""
import pathlib
import subprocess
import sys
import time

root = pathlib.Path(__file__).resolve().parents[1]
base = ["godot", "--headless", "--path", str(root), "--script", "tests/six_peer.gd", "--"]
processes = []
try:
    processes.append(subprocess.Popen(base + ["--test-host"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
    time.sleep(0.8)
    for index in range(5):
        champion = ["Ember", "Luminary", "Vanguard"][index % 3]
        processes.append(subprocess.Popen(base + [f"--champion={champion}"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
    failed = False
    for index, process in enumerate(processes):
        output, _ = process.communicate(timeout=30)
        print(f"PEER {index}\n{output}")
        failed |= process.returncode != 0 or "ERROR:" in output
    sys.exit(1 if failed else 0)
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
