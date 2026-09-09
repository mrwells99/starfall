"""Linux local benchmark: python tools/measure_server.py [--path CHECKOUT] [--port 27944].

Uses two isolated 8-second server runs, one idle and one with six bots. CPU is
percent of one logical core, RSS is process resident memory (not Docker's metric).
This is a short comparison workload, not a player-capacity or latency guarantee.
"""
import argparse
import os
import pathlib
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--path', type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
parser.add_argument('--port', type=int, default=27944)
args = parser.parse_args()

for scenario in ('idle', 'team'):
    with tempfile.TemporaryDirectory(prefix='starfall-bench-') as directory:
        log_path = pathlib.Path(directory) / 'output.log'
        with log_path.open('w') as log:
            command = ['godot', '--headless', '--path', str(args.path), '--script',
                       'tools/server_benchmark.gd', '--log-file', directory + '/godot.log',
                       '--', '--dedicated', f'--port={args.port}', f'--bench-{scenario}']
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                       env=dict(os.environ, XDG_DATA_HOME=directory))
            try:
                deadline = time.monotonic() + 20
                while 'BENCH READY' not in log_path.read_text():
                    if process.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError('Server failed to start:\n' + log_path.read_text())
                    time.sleep(0.05)
                samples = []
                for _ in range(6):
                    proc = pathlib.Path(f'/proc/{process.pid}')
                    # Fields after the parenthesized process name start at field 3.
                    fields = (proc / 'stat').read_text().rsplit(')', 1)[1].split()
                    cpu = (int(fields[11]) + int(fields[12])) / os.sysconf('SC_CLK_TCK')
                    rss = next(int(line.split()[1]) for line in (proc / 'status').read_text().splitlines()
                               if line.startswith('VmRSS:'))
                    samples.append((time.monotonic(), cpu, rss))
                    time.sleep(1)
                process.wait(timeout=20)
                output = log_path.read_text()
                if process.returncode or 'ERROR:' in output or 'BENCH DONE' not in output:
                    raise RuntimeError('Benchmark failed:\n' + output)
                cpu_percent = 100 * (samples[-1][1] - samples[0][1]) / (samples[-1][0] - samples[0][0])
                print(f'{scenario}: CPU {cpu_percent:.1f}% of one core; peak sampled RSS '
                      f'{max(sample[2] for sample in samples) / 1024:.1f} MiB')
                print('\n'.join(line for line in output.splitlines() if line.startswith('BENCH')))
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
