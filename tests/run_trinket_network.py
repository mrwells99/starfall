"""Use the bounded real ENet harness for the shared stun-break ability."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = (root/'tests/run_ember_network.py').read_text()
source = source.replace('ember_network_peer.gd','trinket_network_peer.gd').replace('EMBER NETWORK','TRINKET NETWORK').replace('Ember','Trinket')
exec(compile(source,str(__file__),'exec'),{'__file__':str(__file__),'__name__':'__main__'})
