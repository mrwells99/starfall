"""Run the Outlaw ENet fixture using the established bounded two-peer harness."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
# Reuse orchestration without maintaining a second subprocess/thread lifecycle.
source=(root/'tests/run_ember_network.py').read_text()
source=source.replace('ember_network_peer.gd','outlaw_network_peer.gd').replace('EMBER NETWORK','OUTLAW NETWORK').replace('Ember','Outlaw')
exec(compile(source,str(__file__),'exec'),{'__file__':str(__file__),'__name__':'__main__'})
