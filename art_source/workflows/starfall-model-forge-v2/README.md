# Starfall Model Forge v2

**Default character workflow approved 2026-09-09.** Based on the accepted Fulcrum model, textures, preset anatomy, weapon and animation refinements through r008. The two reverted jump-body experiments are excluded.

Invoke: **“Use Starfall Model Forge v2 for [class] with this reference.”** The saved `$starfall-character-forge` skill now routes here.

| File | Purpose |
| --- | --- |
| [WORKFLOW.md](WORKFLOW.md) | Complete production procedure and local commands |
| [runtime_contract.json](runtime_contract.json) | Exact accepted animation/presentation settings |
| [feedback.json](feedback.json) | Accepted decisions and explicit rejection ledger |
| [new_character.template.json](new_character.template.json) | Start a new class record |
| `manifest.json` | Exact source hashes and archive inventory |
| `contracts.json.gz` | Rig/rest transforms, every clip at keys and half frames, mesh/material/packed-image details |
| `baseline.zip.001`, `.002`, etc. | Ordered parts of one standard ZIP containing the real Blender sources, library/license, GLB, textures, builders, accepted runtime and checks |

Each archive part is at most **32 MiB**, avoiding the earlier oversized single-file GitHub problem. From the project root:

```powershell
python tools/model_forge_snapshot.py --verify
python tools/model_forge_snapshot.py --extract artifacts/forge-v2-new-class-seed
```

Use the configured Python path in WORKFLOW.md if `python` is unavailable. Extraction requires an empty destination and never installs over the live game. This is a character-production kit, not a full playable-game backup. Integration-context files explain hookups; preserve newer gameplay when installing a class.

The baseline fixes anatomy, animation, timing and production method. The new reference supplies appearance, palette and equipment. Exact archived bytes can be recovered; a different character necessarily has intentional visual differences. Keep Character Forge v1 intact as history. Rejected r006/r007 appear only as rejection notes, never as reusable source, model, test or preview files.
