"""Isolated first-shot experiment: real ENet latency, production camera/validation.

GODOT must point at the game binary; GODOT_SERVER optionally selects a different
dedicated-server version. Example:
  python tests/run_aim_mode_tracking_probe.py --rtt 150 --gated --trials 10
This does not wire the experimental history policy into any production scene.
"""
import argparse
import contextlib
import json
import os
from pathlib import Path
import subprocess
import threading

from network_latency import LatencyRelay

parser = argparse.ArgumentParser()
parser.add_argument("--rtt", type=int, default=0)
parser.add_argument("--hold", type=int, default=0)
parser.add_argument("--trials", type=int, default=10)
parser.add_argument("--gated", action="store_true")
parser.add_argument("--jitter", type=float, default=0, help="+/- milliseconds of per-direction packet jitter")
parser.add_argument("--loss", type=float, default=0, help="Percentage of UDP packets dropped, including ACKs")
parser.add_argument("--seed", type=int, default=12345)
parser.add_argument("--motion", choices=["slow", "fast", "jump"], default="slow")
parser.add_argument("--distance", type=float, default=6)
parser.add_argument("--cancel-entry", action="store_true")
parser.add_argument("--production", action="store_true", help="Use the production aim/ping tracking policy")
parser.add_argument("--require-all-hits", action="store_true")
args = parser.parse_args()
if not 0 <= args.rtt <= 500 or not 0 <= args.jitter <= 100 or not 0 <= args.loss <= 10:
    parser.error("Probe limits: RTT 0..500 ms, jitter 0..100 ms, loss 0..10 percent")
if not 3 <= args.trials <= 20 or not 3 <= args.distance <= 15:
    parser.error("Probe limits: 3..20 trials, distance 3..15 meters")
root = Path(__file__).resolve().parents[1]
base = [os.environ.get("GODOT", "godot"), "--headless", "--path", str(root),
        "--script", "tests/aim_mode_tracking_probe.gd", "--",
        f"--test-rtt-ms={args.rtt}", f"--probe-hold-ms={args.hold}",
        f"--probe-trials={args.trials}", f"--probe-motion={args.motion}",
        f"--probe-distance={args.distance}"]
if args.gated:
    base.append("--probe-gated")
if args.production:
    base.append("--probe-production")
if args.cancel_entry:
    base.append("--probe-cancel-entry")
use_relay = bool(args.rtt or args.jitter or args.loss)
if use_relay:
    base.append("--probe-relay")
relay = LatencyRelay(53207, 53206, args.rtt, jitter_ms=args.jitter,
                     loss_percent=args.loss, seed=args.seed) if use_relay else contextlib.nullcontext()
host = client = None
with relay:
    try:
        ready = threading.Event()
        lines = []
        host_base = [os.environ.get("GODOT_SERVER", base[0]), *base[1:]]
        host = subprocess.Popen(host_base + ["--test-host"], stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")

        def read_host():
            for line in host.stdout:
                lines.append(line)
                if "PROBE NETWORK READY" in line:
                    ready.set()
        reader = threading.Thread(target=read_host, daemon=True)
        reader.start()
        if not ready.wait(30):
            raise RuntimeError("Probe host did not start:\n" + "".join(lines))
        client = subprocess.Popen(base, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True, encoding="utf-8", errors="replace")
        output, _ = client.communicate(timeout=70)
        host.wait(timeout=10)
        reader.join(timeout=2)
        host_output = "".join(lines)
        print(host_output + output, flush=True)
        if (host.returncode or client.returncode or "ERROR:" in host_output + output
                or "PROBE HOST PASS" not in host_output or "PROBE CLIENT PASS" not in output):
            raise RuntimeError("Probe infrastructure failed (a rejected shot itself is a valid experiment result)")
        summary = json.loads(next(line.removeprefix("PROBE_SUMMARY ") for line in output.splitlines()
                                  if line.startswith("PROBE_SUMMARY ")))
        speeds = [row["target_speed_mps"] for row in summary["results"]]
        positions = [row["target_x"] for row in summary["results"]]
        if args.motion == "jump":
            heights = [row["target_y"] for row in summary["results"]]
            if max(heights) - min(heights) < .3:
                raise RuntimeError("Jumping-target fixture failed: target did not actually jump")
        elif max(speeds) < .1 or (args.trials >= 3 and max(positions) - min(positions) < .1):
            raise RuntimeError("Moving-target fixture failed: target did not actually strafe")
        summary.update(jitter_ms=args.jitter, loss_percent=args.loss, seed=args.seed,
                       motion=args.motion, distance=args.distance, cancel_entry=args.cancel_entry,
                       relay_packets=relay.received if use_relay else 0,
                       relay_dropped=relay.dropped if use_relay else 0)
        summary["constant_tracking_shots"] = sum(row["constant_tracking"] for row in summary["results"])
        summary["minimum_trigger_charge_ms"] = min(row["trigger_charge_ms"] for row in summary["results"])
        print("EXPERIMENT", json.dumps({key: value for key, value in summary.items() if key != "results"}))
        if args.production and summary["minimum_trigger_charge_ms"] < 580:
            raise RuntimeError("Production shot bypassed the .6s charge (allowing one physics frame of measurement tolerance)")
        if args.require_all_hits and (summary["hits"] != args.trials or summary["fired"] != args.trials):
            raise SystemExit(2)
    finally:
        for process in (client, host):
            if process is not None and process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
