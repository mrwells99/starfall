"""Exercise camera-ray bursts with the bounded two-peer ENet harness."""
from pathlib import Path
from contextlib import nullcontext
import sys
from network_latency import LatencyRelay
root=Path(__file__).resolve().parents[1]
source=(root/'tests/run_ember_network.py').read_text()
source=source.replace('ember_network_peer.gd','detonation_network_peer.gd').replace('EMBER NETWORK','DETONATION NETWORK').replace('Ember','Detonation')
rtt = next((int(arg.split('=', 1)[1]) for arg in sys.argv[1:] if arg.startswith('--test-rtt-ms=')), 0)
if not 0 <= rtt <= 500:
    raise ValueError('Test RTT must be between 0 and 500ms')
with LatencyRelay(53197, 53196, rtt) if rtt else nullcontext():
    print(f'Detonation transport RTT delay: {rtt}ms', flush=True)
    exec(compile(source,str(__file__),'exec'),{'__file__':str(__file__),'__name__':'__main__'})
