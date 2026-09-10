"""Exercise camera-ray bursts with the bounded two-peer ENet harness."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'tests/run_ember_network.py').read_text()
source=source.replace('ember_network_peer.gd','detonation_network_peer.gd').replace('EMBER NETWORK','DETONATION NETWORK').replace('Ember','Detonation')
exec(compile(source,str(__file__),'exec'),{'__file__':str(__file__),'__name__':'__main__'})
