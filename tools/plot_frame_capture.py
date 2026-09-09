"""Create a standalone frame-time figure from recorded measurements.
Usage: python tools/plot_frame_capture.py artifacts/frame-capture
Requires matplotlib; no running-game changes.
"""
import csv
import json
import pathlib
import sys

base = pathlib.Path(sys.argv[1])
if (base / 'python-deps').exists():
    sys.path.insert(0, str(base / 'python-deps'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

cases = [('forward-baseline', 'Unchanged game'), ('forward-no-beams', 'Control: impact beams disabled'),
         ('forward-production-fix', 'Fixed game: stable emission + cached, prewarmed impacts')]
fig, axes = plt.subplots(3, 2, figsize=(15, 10), sharex=True, sharey=True)
fig.patch.set_facecolor('#f7f8fb')
for row, (name, title) in enumerate(cases):
    with (base / name / 'frames.csv').open() as file:
        frames = [{k: float(v) for k, v in entry.items()} for entry in csv.DictReader(file)]
    for number in [1, 2]:
        ax = axes[row, number-1]
        data = [f for f in frames if f['round'] == number and not f['round_boundary']]
        x = [f['physics_tick'] / 60 for f in data]
        y = [f['wall_us'] / 1000 if f['focused'] and f['effective_cap'] == 60 else np.nan for f in data]
        ax.plot(x, y, color='#6947b7' if number == 1 else '#176b88', linewidth=.7)
        ax.axhline(16.667, color='#758193', linewidth=.7, linestyle='--')
        ax.axhline(50, color='#bc6235', linewidth=.8, linestyle=':')
        ax.set_yscale('log')
        ax.set_ylim(9, 1100)
        ax.set_xlim(0, 40)
        ax.set_yticks([10, 16.667, 50, 100, 250, 1000], ['10', '16.7', '50', '100', '250', '1000'])
        ax.grid(axis='y', alpha=.17)
        valid = [v for v in y if np.isfinite(v)]
        count = sum(v > 50 for v in valid)
        ax.set_title(f'{title}\nRound {number} | max {max(valid):.1f} ms | {count} frames >50 ms', fontsize=10, loc='left')
        ax.spines[['top', 'right']].set_visible(False)
        if number == 1: ax.set_ylabel('Individual frame interval (ms, log scale)')
        if row == 2: ax.set_xlabel('Simulation time (seconds; identical recorded combat actions)')
axes[0,0].annotate('864 ms: first Charge impact', xy=(.55, 864), xytext=(5, 680),
                   arrowprops={'arrowstyle':'->', 'color':'#5c4769'}, fontsize=9, color='#5c4769')
fig.suptitle('Starfall 3v3 — measured impact stalls before and after the fix', fontsize=17, x=.07, ha='left')
fig.text(.07, .935, '0.11.0 / Godot 4.7.2 · Forward+ Vulkan · RTX 5060 Ti / 616.64 · Ryzen 7 7700X · 2560×1440 · Balanced / 100% / 60 FPS', fontsize=10)
fig.text(.07, .024, 'Raw monotonic frame-end intervals; async GPU timing is recorded separately. Round boundaries and unfocused intervals are excluded.\nEach pair replays the same 586 cast/resolve/impact events. The bottom row tests the production fix with all combat effects enabled.', fontsize=9, color='#4c5667')
fig.subplots_adjust(left=.07, right=.985, top=.885, bottom=.10, hspace=.37, wspace=.13)
fig.savefig(base / 'frame-times.png', dpi=150, facecolor=fig.get_facecolor())
fig.savefig(base / 'frame-times.svg', facecolor=fig.get_facecolor())
print(base / 'frame-times.png')
