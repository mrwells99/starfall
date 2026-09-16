"""Record only the native Ember review window at 30 fps on Linux/X11.

Run from any directory; requires Godot, FFmpeg, xwininfo and a live X11 display.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/ember-particles'

def main():
    for name in ['godot','ffmpeg','xwininfo']:
        if not shutil.which(os.environ.get(name.upper(),name)):
            raise SystemExit(f'Missing {name}; use the Godot image-sequence review instead.')
    if not os.environ.get('DISPLAY'):
        raise SystemExit('A live X11 DISPLAY is required; do not use this as a headless benchmark.')
    OUT.mkdir(parents=True,exist_ok=True)
    with (OUT/'video-godot.log').open('w') as log:
        game=subprocess.Popen([os.environ.get('GODOT','godot'),'--path',str(ROOT),'--log-file',str(OUT/'video-engine.log'),'--script','tools/ember_particle_review.gd'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+30
            window=None
            while time.monotonic()<deadline and game.poll() is None:
                tree=subprocess.run(['xwininfo','-root','-tree'],capture_output=True,text=True,check=True).stdout
                match=re.search(r'(0x[0-9a-f]+) "Starfall · Ember particle workflow r001"',tree)
                if match:
                    candidate=int(match[1],16)
                    details=subprocess.run(['xwininfo','-id',hex(candidate)],capture_output=True,text=True,check=True).stdout
                    if re.search(r'Width:\s+1280\b',details) and re.search(r'Height:\s+800\b',details):
                        window=candidate;break
                time.sleep(.1)
            if window is None:raise RuntimeError('Ember review window did not appear')
            with (OUT/'video-encoder.log').open('w') as encoder_log:
                subprocess.run([os.environ.get('FFMPEG','ffmpeg'),'-y','-hide_banner','-f','x11grab','-window_id',str(window),'-video_size','1280x800','-draw_mouse','0','-framerate','30','-i',os.environ['DISPLAY'],'-t','35','-an','-c:v','libx264','-preset','veryfast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'ember-review.mp4')],stdout=encoder_log,stderr=subprocess.STDOUT,check=True,timeout=50)
            game.wait(timeout=45)
            if game.returncode:raise RuntimeError('Godot preview failed; inspect video-godot.log')
            seconds=float(subprocess.check_output([os.environ.get('FFPROBE','ffprobe'),'-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(OUT/'ember-review.mp4')],text=True))
            if seconds<30:raise RuntimeError('Capture ended early; inspect video-encoder.log')
        finally:
            if game.poll() is None:game.terminate();game.wait(timeout=5)
    print(OUT/'ember-review.mp4')
if __name__=='__main__':main()
