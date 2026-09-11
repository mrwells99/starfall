# Starfall

A Godot 4.5 arena-combat prototype: **WoW-style controls** (WASD, mouse turn, strafe, Tab targeting, third-person camera) with **LoL-style structure** (pick a fixed-kit champion, enter an arena at equal power — no gear, no leveling). Original names and generated placeholder geometry; no WoW/LoL assets.

**Theme: Cosmic Gladiators.** Fighters summoned from different worlds and universes fight in an ancient arena floating in space — celestial temples, nebulae, ancient gods watching. Deep purples/blues with extremely bright magical accents. Established canon; details in [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md).

- **Full vision, champions, combat mechanics:** [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)
- **Where the project is right now:** [`docs/CONTEXT.md`](docs/CONTEXT.md)
- **How the code is put together:** [`docs/TECHNICAL_ARCHITECTURE.md`](docs/TECHNICAL_ARCHITECTURE.md)
- **What we're building next:** [`docs/ROADMAP.md`](docs/ROADMAP.md)
- **Why decisions were made:** [`docs/DECISIONS.md`](docs/DECISIONS.md)
- **How it gets deployed:** [`DEPLOYMENT.md`](DEPLOYMENT.md)
- **Art direction:** [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md)

## For players

Packaged desktop launchers install and update the game without the editor: [Windows](docs/WINDOWS_DISTRIBUTION.md) and [Linux (Ubuntu / Arch)](docs/LINUX_DISTRIBUTION.md). Linux support is prepared locally and awaits its first deployment.

Open `project.godot` in Godot 4.5 and press **F5**, or run `godot --path .`. It opens borderless fullscreen at your monitor's resolution; **F11** or **Alt+Enter** toggles back to a window. Pick a champion → **Online** or **Offline**. Controls and champion abilities are in [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

The arena now launches with **Forward+ Balanced graphics** and a **60 FPS gameplay limit** by default. Settings offers High (the previous lighting profile), Performance, a frame limit, 3D resolution scaling, and Show FPS. Menus/results use 30 FPS and unfocused windows 15 FPS. Restart the game to pick up the change. Open `scenes/sanctum_corner_preview.tscn` and run the scene for independent before/after and High lighting switches, orbit and zoom. Launch with `--rendering-method gl_compatibility` for Compatibility, or append `-- --sanctum-high` to force the old High profile or `-- --sanctum-base` for the original base-effects comparison. See [`docs/FORWARD_PLUS_ASSESSMENT.md`](docs/FORWARD_PLUS_ASSESSMENT.md) for hardware observations and measurement limits.

---

# For AI agents — this repository is your shared memory

Multiple AI agents (Claude Code, Cursor, Codex, and others) collaborate here. You are one of them. The repository is designed as the **persistent shared memory** across sessions and tools: what you know when you start is what previous agents wrote down.

Your job is not only to make the requested change, but to leave the memory in a state where the next agent can continue seamlessly.

> `CLAUDE.md` is a symlink to `README.md` so Claude Code auto-loads this content. **Do not break the symlink.** On Windows checkouts with symlinks disabled: `git config core.symlinks true` and re-checkout.

## The docs/ system

Detailed, evolving project knowledge lives under `docs/`. Each file has a specific role:

| File | Role |
| --- | --- |
| [`docs/CONTEXT.md`](docs/CONTEXT.md) | **Short-term memory.** Current milestone, objective, recent work, blockers, immediate next steps. |
| [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) | **Source of truth** for established game design — modes, champions, ability values, combat rules, controls, non-negotiables. |
| [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md) | **Source of truth** for established visual direction. |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | **Long-term reasoning memory.** Meaningful decisions and *why* — the constraints you shouldn't silently reverse. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | **Source of truth** for development priorities. |
| [`docs/TECHNICAL_ARCHITECTURE.md`](docs/TECHNICAL_ARCHITECTURE.md) | Code map, runtime state, combat pipeline, networking, tests, troubleshooting. |
| [`DEPLOYMENT.md`](DEPLOYMENT.md) | **Production deployment.** Docker image, GHCR, GitHub Actions, server bootstrap, secrets, rollback, verification, security review. |
| [`docs/DEPLOY.md`](docs/DEPLOY.md) | Droplet facts — DNS, firewall, SELinux — plus the superseded systemd model kept as a fallback. |

**You may create new `docs/*.md` files** when an area of the project becomes a substantial, recurring area of knowledge (e.g. `docs/CHAMPIONS.md`, `docs/VFX_GUIDELINES.md`, `docs/DEPLOY.md`). Do not create a file per topic. Use judgment: a new file exists because it represents durable, recurring knowledge — not because you have five paragraphs to say once.

## Workflow

### Before substantial work

1. Read this file.
2. Read [`docs/CONTEXT.md`](docs/CONTEXT.md) — what's happening now.
3. Identify which domain(s) the task touches (design? architecture? deploy? art?).
4. Read the relevant `docs/*.md` files.
5. Check [`docs/DECISIONS.md`](docs/DECISIONS.md) for constraints or prior reasoning that affects your approach.
6. Check [`docs/ROADMAP.md`](docs/ROADMAP.md) when the task relates to priorities.

**Read only what you need.** Do not load every document.

### After substantial work — did this create durable new knowledge?

If yes, update the appropriate doc (prefer editing over appending):

| Type of change | Where to update |
| --- | --- |
| Gameplay design decision | [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) |
| Visual / art direction | [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md) |
| Meaningful architectural or product decision | [`docs/DECISIONS.md`](docs/DECISIONS.md) |
| Milestone or priority change | [`docs/ROADMAP.md`](docs/ROADMAP.md) |
| "What is currently being worked on" | [`docs/CONTEXT.md`](docs/CONTEXT.md) |
| Architecture / runtime / protocol change | [`docs/TECHNICAL_ARCHITECTURE.md`](docs/TECHNICAL_ARCHITECTURE.md) |

If none of the above apply — as with most changes — the docs stay as they are.

### Deciding what to write down

Ask: **"Would a future AI agent need to know this in order to make a good decision about this project?"**

Yes → persistent doc. No → do not write it.

**Avoid:** conversation transcripts, huge AI-generated summaries, duplicate information (put it in one place and link to it), temporary implementation details, speculative ideas presented as facts, one-off choices that don't constrain future work.

## Information promotion — facts vs ideas

Ideas exist at levels of certainty:

```
Conversation / brainstorming
          ↓
     Possible idea
          ↓
   Proposed direction
          ↓
  Established decision
          ↓
Project canon / source of truth
```

**Do not silently promote brainstorming into project canon.** If something is exploratory, label it that way in the doc — `Proposed:`, `Exploring:`, `Rejected:`. Only established decisions belong in `DECISIONS.md` as canonical entries. Only established design belongs in `GAME_DESIGN.md` as canonical entries.

When you write to a docs file, keep sections that separate:

- **Current / established** (canon)
- **Proposed / exploring** (candidates for promotion)
- **Rejected** (options considered and set aside — recorded so they aren't relitigated)

## Conflict resolution

If you find contradictory information across docs (or between docs and code):

1. Identify which document is supposed to be authoritative for that domain (see table above).
2. Check whether one entry is stale — `git log`, current source, and freshly-run test results are authority when older prose disagrees.
3. If the conflict represents an unresolved design question, document it as such in the appropriate file. **Do not silently pick one.**
4. If unclear, ask the human before making a call.
5. Once resolved, update the source-of-truth document and remove stale entries.

## Non-negotiable rules

Constraints the user has explicitly set. Do not silently reverse. Reasoning is in [`docs/DECISIONS.md`](docs/DECISIONS.md).

- **Gameplay direction is WoW-style controls + LoL-style structure.** No top-down camera. No click-to-move. No gear system. No leveling.
- **The theme is Cosmic Gladiators** — space + fantasy, an ancient arena floating in space, summoned fighters from across universes, deep purples/blues with bright magical accents. Established by the user. Do not drift to a different setting or palette; see [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md).
- **Character models and overhead nameplates are never clickable target-select surfaces.** Target via Tab, F1–F3, or clickable UI frames only.
- **Off-GCD does not bypass "already casting".** No ability can be used while another cast is in progress.
- **Server is authoritative for combat.** Do not add client-authoritative combat state to hide lag — fix with prediction instead.

## Quick reference — running and testing

Full details in [`docs/TECHNICAL_ARCHITECTURE.md`](docs/TECHNICAL_ARCHITECTURE.md).

```sh
# First run on a fresh clone — builds the import cache for the icon assets.
# Test scripts do not import on their own and will fail without this.
godot --headless --path . --import

# Play locally:
godot --path .

# Combat integration:
godot --headless --path . --script tests/combat_test.gd

# Networked (sequential — all share UDP 27840):
python3 tests/run_network.py
python3 tests/run_network.py --test-team --test-latency
python3 tests/run_six.py
python3 tests/run_dedicated.py
python3 tests/run_lobby.py
python3 tests/run_world.py

# Art and icons (real window):
godot --path . --script tests/ability_art_test.gd
godot --path . --script tests/map_test.gd

# World mode (headless):
godot --headless --path . --script tests/world_test.gd

# Real-window UI test (rejects --headless):
godot --path . --script tests/ui_test.gd
```

## References

- [Godot 4.5 Viewport input and coordinates](https://docs.godotengine.org/en/4.5/classes/class_viewport.html)
- [Mouse capture / input coordinates](https://docs.godotengine.org/en/stable/tutorials/inputs/mouse_and_input_coordinates.html)
- [High-level multiplayer](https://docs.godotengine.org/en/4.4/tutorials/networking/high_level_multiplayer.html)
- [AStarGrid2D](https://docs.godotengine.org/en/4.4/classes/class_astargrid2d.html)
- [Byte-array compression](https://docs.godotengine.org/en/4.4/classes/class_packedbytearray.html)
