"""Use the established bounded two-peer runner; add --remote for observer view."""
from pathlib import Path

source = (Path(__file__).resolve().parent / "run_ember_network.py").read_text()
source = source.replace("ember_network_peer.gd", "backflip_network_peer.gd")
source = source.replace("EMBER NETWORK", "BACKFLIP NETWORK").replace("Ember", "Backflip")
exec(compile(source, __file__, "exec"), {"__file__": __file__, "__name__": "__main__"})
