"""Bounded local A/B test; does not connect to or change the hosted server."""
import argparse
import ctypes
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/aimed-combat'

class MemoryCounters(ctypes.Structure):
    _fields_ = [('cb', ctypes.c_ulong), ('faults', ctypes.c_ulong)] + [
        (name, ctypes.c_size_t) for name in ('peak_working_set', 'working_set',
        'peak_paged', 'paged', 'peak_nonpaged', 'nonpaged', 'pagefile', 'peak_pagefile', 'private')]

def run(godot, fitted):
    # The Windows console executable is a tiny launcher. Measure the engine
    # executable itself, otherwise its child's memory would be missed.
    engine = Path(godot)
    direct = engine.with_name(engine.name.replace('_console.exe', '.exe'))
    if direct.exists():
        godot = str(direct)
    label = 'fitted' if fitted else 'baseline'
    command = [godot, '--headless', '--path', str(ROOT), '--log-file',
               str(OUT / (label + '-engine.log')), '--script', 'tools/hitbox_benchmark.gd',
               '--', '--dedicated', '--port=53244']
    if not fitted:
        command.append('--without-hitboxes')
    peak_working = peak_private = 0
    with (OUT / (label + '-process.log')).open('w', encoding='utf8') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        memory_info = ctypes.WinDLL('psapi').GetProcessMemoryInfo
        memory_info.argtypes = [ctypes.c_void_p, ctypes.POINTER(MemoryCounters), ctypes.c_ulong]
        handle = kernel.OpenProcess(0x410, False, process.pid)
        start = time.monotonic()
        try:
            while process.poll() is None:
                if time.monotonic() - start > 45:
                    raise RuntimeError('Benchmark timeout')
                counters = MemoryCounters()
                counters.cb = ctypes.sizeof(counters)
                if handle and memory_info(handle, ctypes.byref(counters), counters.cb):
                    peak_working = max(peak_working, counters.working_set)
                    peak_private = max(peak_private, counters.private)
                time.sleep(.1)
        finally:
            if handle:
                kernel.CloseHandle(handle)
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
    output = (OUT / (label + '-process.log')).read_text(encoding='utf8')
    if process.returncode != 0 or 'ERROR:' in output or 'HITBOX_BENCHMARK ' not in output:
        raise RuntimeError(output)
    result = json.loads((OUT / (label + '-benchmark.json')).read_text())
    if peak_private < result['static_bytes']:
        raise RuntimeError('Process memory sample did not include the Godot engine')
    result.update(peak_working_set_bytes=peak_working, peak_private_bytes=peak_private)
    print(json.dumps(result), flush=True)
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    results = [run(args.godot, False), run(args.godot, True)]
    (OUT / 'benchmark-comparison.json').write_text(json.dumps({
        'method': 'Windows dedicated Godot; 6 moving characters; 2 s warmup + 600 individual 60 Hz ticks per condition; six cooldown presses every 0.5 s; no remote clients; background user activity uncontrolled. Host capacity is not measured.',
        'results': results}, indent=2))
