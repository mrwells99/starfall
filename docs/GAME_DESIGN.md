# Game Design — established source of truth

_Established design lives here. Open questions and rejected ideas are labeled explicitly. If a value here diverges from the code (`scripts/kits.gd`, `scripts/arena.gd`), **the code is authoritative** — update this file to match._

## Vision

Starfall combines **World of Warcraft's gameplay and controls** with **League of Legends' pick-a-champion, enter-a-match structure**.

The comparison to League concerns roster shape and lack of gearing — **not** its camera, movement, targeting, map, lanes, or economy. All of those follow the WoW side of the split.

### Setting — Cosmic Gladiators

Fighters from different worlds and universes are summoned to compete in an **ancient cosmic arena**: space + fantasy, an arena floating in space rather than standing on a planet, ancient gods watching from massive structures. Champions may be alien assassins, celestial knights, or weird cosmic beasts.

This is established canon. The fiction is the in-world reason combatants meet at equal power with no gear and no leveling. Full theme and visual identity — deep purples/blues, bright magical accents, nebulae, glowing weapons — live in [`ART_DIRECTION.md`](ART_DIRECTION.md); reasoning is in [`DECISIONS.md`](DECISIONS.md).

Intended experience:

1. Pick an original champion with a complete, fixed specialization-like kit.
2. Enter an arena with equal starting power. No leveling. No gearing before or during the match.
3. Win through movement, positioning, line of sight, cooldown trading, interrupts, crowd control, healing, and team coordination.
4. Eventually support an accessible queue and competitive team matches.

## Game modes

**Duel · 1v1** — two players, one champion each.

**Team arena · 3v3** — six players per match, three per team. Local sparring auto-fills a team with a healer, melee fighter, and ranged caster if role slots are empty. Human champion choices in networked matches are unrestricted.

A three-second countdown starts each round. A round ends when every member of one team is dead. Teammates keep fighting when one falls. No resurrection, no respawn during a round.

## Champions

Four fixed-kit champions. Each has seven abilities on keys 1–7.

| Key | Ember — ranged | Vanguard — melee | Luminary — healer | Fulcrum — control |
| --- | --- | --- | --- | --- |
| 1 | Firebolt — casted damage | Cleave — melee damage | Smite — casted damage | Collapse — casted damage |
| 2 | Flare — instant burst | Crush — melee burst | Renewal — instant ally heal | Tidal Force — instant burst |
| 3 | Disrupt — interrupt | Pummel — melee interrupt | Dispel — remove an ally's stun | Horizon — interrupt |
| 4 | Stasis — casted stun | Bash — melee stun | Rebuke — casted stun | Anchor — casted stun |
| 5 | Ward — damage reduction | Iron Skin — damage reduction | Sanctuary — ally damage reduction | Umbra — damage reduction |
| 6 | Mend — self heal | Mend — self heal | Greater Heal — repeatable ally heal | Mend — self heal |
| 7 | Blink — forward escape | Charge — close on target | Grace — movement speed boost | Tether — pull a fighter to you |

**Fulcrum** is the roster's control champion: mid-range, lowest damage of the three non-healers, and the only champion with no way to reposition *itself*. It decides where the fight happens instead. Every slot but 7 reuses an existing ability kind, so its identity rests almost entirely on Tether.

**Tether** is the only ability in the game that does not care which team its target is on. On an enemy it is a peel and a kill setup — drag a healer out of line of sight, pull a kiting caster into melee. On an ally it is a save. It still requires range, line of sight and facing, because it is an aimed ability either way, and it deals no damage.

### Ability tooltips

One hover, one tooltip. Name, effect, then cast/range/cooldown/cost. There is no Shift-expanded variant — it was removed along with the long rules prose it carried, which duplicated `GAME_DESIGN.md` and drifted from it.

### Cooldown display

WoW-style radial sweep on each hotbar slot, drawn in `scripts/cooldown_overlay.gd`:

- **Ability cooldown** — heavy shade plus an OmniCC-style countdown (minutes when long, whole seconds, tenths at the end). The ability name steps aside while the number shows.
- **Global cooldown** — lighter shade, no number. 1.5s of flickering digits is noise.
- An ability's own cooldown takes the slot when both are running, and an off-GCD ability is never swept by the global cooldown.

The shaded wedge is what is still to come: it starts at the elapsed angle and runs clockwise round to 12 o'clock, so the slot reveals clockwise from the top as it comes off cooldown.

### Cast bars

Two places: the target/player unit frames, and a bar under the overhead nameplate that fills left to right and hides when nothing is casting.

### Current numeric values

Kit dictionaries: `name`, `kind`, `power`, `range`, `cast`, `cd`, `off`. `Kits.get_kit()` returns fresh dictionaries — do not share mutable cooldown state between fighters.

| Champion | Key | Ability / kind | Power | Range | Cast | Own CD | Off GCD |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Ember | 1 | Firebolt / damage | 16 dmg | 28 | 1.5 s | 0 | No |
| Ember | 2 | Flare / damage | 22 dmg | 22 | Instant | 7 s | No |
| Ember | 3 | Disrupt / interrupt | 4 s lock | 22 | Instant | 12 s | Yes |
| Ember | 4 | Stasis / control | 4 s stun | 20 | 0.8 s | 16 s | No |
| Ember | 5 | Ward / shield | 5 s duration | Self | Instant | 22 s | Yes |
| Ember | 6 | Mend / self_heal | 28 healing | Self | 2 s | 16 s | No |
| Ember | 7 | Blink / blink | 8 m travel | Self | Instant | 14 s | Yes |
| Vanguard | 1 | Cleave / damage | 13 dmg | 3.5 | Instant | 0 | No |
| Vanguard | 2 | Crush / damage | 25 dmg | 3.5 | Instant | 7 s | No |
| Vanguard | 3 | Pummel / interrupt | 4 s lock | 4 | Instant | 12 s | Yes |
| Vanguard | 4 | Bash / control | 3 s stun | 3.5 | Instant | 16 s | No |
| Vanguard | 5 | Iron Skin / shield | 5 s duration | Self | Instant | 22 s | Yes |
| Vanguard | 6 | Mend / self_heal | 28 healing | Self | 2 s | 16 s | No |
| Vanguard | 7 | Charge / charge | 6 dmg | 22 | Instant | 12 s | Yes |
| Luminary | 1 | Smite / damage | 10 dmg | 28 | 1.5 s | 0 | No |
| Luminary | 2 | Renewal / heal | 18 healing | 28 | Instant | 7 s | No |
| Luminary | 3 | Dispel / dispel | Remove stun | 28 | Instant | 10 s | Yes |
| Luminary | 4 | Rebuke / control | 3 s stun | 20 | 1 s | 18 s | No |
| Luminary | 5 | Sanctuary / ally_shield | 5 s duration | 28 | Instant | 22 s | Yes |
| Luminary | 6 | Greater Heal / heal | 27 healing | 28 | 1.8 s | 0 | No |
| Luminary | 7 | Grace / sprint | 4 s duration | Self | Instant | 16 s | Yes |
| Fulcrum | 1 | Collapse / damage | 14 dmg | 24 | 1.3 s | 0 | No |
| Fulcrum | 2 | Tidal Force / damage | 20 dmg | 20 | Instant | 7 s | No |
| Fulcrum | 3 | Horizon / interrupt | 4 s lock | 22 | Instant | 12 s | Yes |
| Fulcrum | 4 | Anchor / control | 3.5 s stun | 18 | 0.6 s | 16 s | No |
| Fulcrum | 5 | Umbra / shield | 5 s duration | Self | Instant | 22 s | Yes |
| Fulcrum | 6 | Mend / self_heal | 28 healing | Self | 2 s | 16 s | No |
| Fulcrum | 7 | Tether / pull | 8 m travel | 22 | Instant | 14 s | Yes |

Balance is provisional. Real playtesting has not happened.

## Combat mechanics

**Health** caps at 100. Damage is clamped to remaining health.

**Global cooldown (GCD)** — 1.5 seconds. Abilities with `off: true` bypass it. **No ability can be used while another cast is in progress**, even off-GCD ones.

**Movement, turn, jump:**

- Forward and strafe: 6.5 u/s.
- Backward (positive backward component): 3.8 u/s.
- Keyboard turn: 2.5 rad/s.
- Jump impulse 7; gravity 20.
- Sprint multiplier: 1.65×.

**Line of sight** casts from each actor's position + `Vector3.UP` against world layer 1. Characters do not block each other's spells.

**Offensive facing** — non-negative dot between local forward (`-Z`) and target direction. A forward half-space, not a narrow cone.

**Damage reduction** (Ward / Iron Skin / Sanctuary) — multiplies incoming damage by **0.4 for 5 seconds**. Not an absorb pool. Not CC-immune. Refresh replaces timer; does not stack.

**Interrupts** cancel an active cast and set spell lockout to **4 seconds**. Missing does neither but still spends the cooldown.

**Control (stun) diminishing returns** — all stun types share one DR category:

- Duration factors: 1.0 → 0.5 → 0.25 → 0.0 (immune).
- A successful stun increments DR count and sets reset timer to `18 + duration`.
- Immune attempts do not extend the timer. Dispel clears stun and caps remaining reset to 18 s (without resetting count).
- Damage does not break stun.

**Spell lockout** —
- Ember can use Ward / Blink while locked.
- Luminary can use Grace while locked. Sanctuary is `ally_shield` and is currently blocked while locked.
- **Vanguard ignores spell lockout completely.** Coarse and provisional — see [`DECISIONS.md`](DECISIONS.md).

**Healing dampening** — starts at 60 s, caps at 70 % at **186 s (3:06)**:

```
reduction = clamp((elapsed - 60) / 180, 0, 0.7)
actual_heal = min(missing_health, base_heal * (1 - reduction))
```

Cannot revive the dead.

**Mobility (Blink, Charge)** sweeps the character capsule against real geometry via `move_and_collide()`. Cannot cross pillars or walls. Charge aims to stop 1.8 m short of target and deals damage only if final distance ≤ 3.5 m. No minimum range. No charge stun.

## Controls

Third-person camera. WASD movement. Mouse-turn / strafe. Tab targeting.

| Input | Action |
| --- | --- |
| W / S | Forward / backward |
| A / D | Turn; strafe while holding RMB |
| Q / E | Strafe |
| Space | Jump |
| Hold RMB | Steer character and camera |
| Hold LMB | Orbit camera independently |
| Hold both mouse buttons | Run forward |
| Wheel | Zoom (3–18 m); camera retracts against geometry |
| Tab | Cycle living enemies |
| Click a character / world | Camera control only; **never** changes target |
| F1 / F2 / F3 | Select yourself / first teammate / second teammate |
| Click party / enemy frame | Select that teammate / enemy |
| Click player / target / focus frame | Select the character represented by that frame |
| F / G | Set focus / select focus target |
| 1–7 or hotbar click | Use ability |
| Hover ability | Short effect description |
| Hold Shift while hovering | Full mechanics, values, targeting rules, limitations |
| Escape | Cancel cast → clear target → open panel |

**Character models and overhead nameplates are never clickable target-select surfaces.** See [`DECISIONS.md`](DECISIONS.md) for the incident behind this rule.

Opening the panel stops local movement but does **not** pause combat.

## Target rules

**Self-only spells** (`shield`, `self_heal`, `blink`, `sprint`) always choose the caster. UI selection is not changed.

**Helpful spells with fallback** (`heal`, `ally_shield`, `dispel`) — choose the selected ally; enemy or no selection falls back to self. Dead allies are invalid (not fallback-self).

**Offensive spells** require a selected enemy in range, in line of sight, in the forward half-space.

Helpful spells on other actors require range and sight but not facing. Self spells skip range and sight.

## Team colors and identity

**Absolute** (on model, overhead nameplate): blue = team 0, red = team 1. Do not flip based on viewer.

**Relative** (main health frames): blue = local player's ally, red = enemy. Flip based on viewer.

Do not conflate. Model color is identity; frame color is presentation.

## Non-negotiable rules

These are constraints the user has explicitly set. Reasoning in [`DECISIONS.md`](DECISIONS.md).

- **WoW-style controls + LoL-style structure.** No top-down camera. No click-to-move. No gear system. No leveling.
- **No model or nameplate click-to-target.** Selection is Tab, F1–F3, or unit frames only.
- **Off-GCD does not bypass "already casting".** No ability can be used while another cast is in progress.
- **Server is authoritative for combat.** Clients render server state; they do not send desired HP or position.

## Open questions

_Unresolved design questions. Do not silently promote._

- Balance numbers are provisional.
- Charge on Vanguard is ranged (22 m) but its damage payoff requires ending within 3.5 m. Whether the range/payoff mismatch is a feature is undecided.
- Whether Luminary should be able to cast Sanctuary while spell-locked is undecided (currently blocked).
- Vanguard ignoring spell lockout completely is coarse — real "school" mechanics may replace it.
- No resources (mana / energy / rage) currently exist. Whether they should is open.
- No respawn during a round. Whether Luminary should get a limited resurrection is open.

## Rejected directions

_Considered and set aside. Recorded so they aren't relitigated without new reasoning._

- **Top-down / click-to-move camera** (League-style). Rejected — the WoW gameplay identity requires WASD + mouse-turn + third-person.
- **Gear or item progression during a match.** Rejected — the design premise is equal starting power.
- **Click-to-target on character models.** Rejected — caused specific self-select bugs and undermines the intended explicit targeting framework. See [`DECISIONS.md`](DECISIONS.md).
