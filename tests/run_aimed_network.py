"""Run aimed ability ENet checks using the project's bounded two-peer harness."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = (root/'tests/run_ember_network.py').read_text()
source = source.replace('ember_network_peer.gd', 'aimed_network_peer.gd').replace('EMBER NETWORK', 'AIMED NETWORK').replace('Ember', 'Aimed')
exec(compile(source, str(__file__), 'exec'), {'__file__': str(__file__), '__name__': '__main__'})
