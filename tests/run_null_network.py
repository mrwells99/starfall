"""Exercise Null's owner and enemy views over the bounded ENet harness."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'tests/run_ember_network.py').read_text(encoding='utf-8')
source=source.replace('ember_network_peer.gd','null_network_peer.gd').replace('EMBER NETWORK','NULL NETWORK').replace('Ember','Null')
exec(compile(source,str(__file__),'exec'),{'__file__':str(__file__),'__name__':'__main__'})
