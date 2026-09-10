# Starfall Model Forge v2 — active workflow

**Required extension approved 2026-09-10: body hitbox creation.** The owner requested that the completed five-class hitbox process become part of Model Forge v2. Every future class now ships its model, textures, accepted animations **and fitted animated hitboxes**, with pictures and checks.

Read the original [README](README.md), [production procedure](WORKFLOW.md), [runtime contract](runtime_contract.json) and [feedback ledger](feedback.json), then complete the required [hitbox procedure](extensions/hitboxes-v1/WORKFLOW.md). Use the extended [new-character record](extensions/hitboxes-v1/new_character.template.json), which includes all original fields plus hitbox deliverables and evidence.

The active standard is **v2 + hitboxes-v1**. The original Fulcrum archive, anatomy, textures, motion contracts and rejected-revision exclusions remain byte-for-byte intact. This explicitly requested extension supersedes the original prohibition on extending the workflow under the v2 name; it does not revise approved animation or restore r006/r007. Future changes to this extension need a separately recorded revision, not silent replacement of its frozen source.

From the project root (use the installed Python path from WORKFLOW.md if necessary):

```powershell
python tools/model_forge_hitbox_snapshot.py --verify
python tools/model_forge_hitbox_snapshot.py --new-record CLASS --record artifacts/CLASS-STAGE/forge-record.json
```

The verifier checks both the original 77-file baseline and the hitbox extension. For recovery, extract them into **separate empty staging directories**:

```powershell
python tools/model_forge_snapshot.py --extract artifacts/CLASS-BASE-SEED
python tools/model_forge_hitbox_snapshot.py --extract artifacts/CLASS-HITBOX-SEED
```

Read frozen hitbox tools as the accepted reference; adapt them to the current checkout and new class. Archived arena/combatant/presenter files are integration context, never an instruction to overwrite current gameplay. No playable aimed spell is implied by character creation.

Before delivery, fill the class record and run:

```powershell
python tools/model_forge_hitbox_snapshot.py --check-record artifacts/CLASS-STAGE/forge-record.json
```

This checks the hitbox completion evidence; the original Blender, skin, material and animation checks still apply. Preview on the second monitor, use reversible installation, and include the actual hitbox pictures in the final handoff. No push or deployment is implied.
