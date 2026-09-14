"""Run spell queue input and replication over delayed ENet."""
from pathlib import Path
source = Path(__file__).with_name('run_ember_network.py').read_text()
source = source.replace('ember_network_peer.gd', 'spell_queue_network_peer.gd').replace('EMBER NETWORK', 'SPELL QUEUE NETWORK').replace('Ember', 'Spell queue')
exec(compile(source, __file__, 'exec'))
