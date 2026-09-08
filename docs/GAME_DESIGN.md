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

**World** — a persistent hangout on the arena map. One always-running server, no queue, no lobby, no rounds, no timer and no victory. You walk in, you are there, and other people are walking around with you.

**Damage is refused between people who have not agreed to a duel**, so standing around is safe and every fight is one both people chose. Target someone and press **C** to challenge; they press **Y** to accept. Both are restored to full health and cleared of stuns when a duel begins, so it is never decided by who was already hurt. Losing ends the duel and brings you back at full health a few seconds later — there is no death in the world, only a defeat.

A bystander cannot damage either duellist. Latecomers are spawned into the running world without restarting it for anyone already there.

**Team arena · 3v3** — six players per match, three per team. Local sparring auto-fills a team with a healer, melee fighter, and ranged caster if role slots are empty. Human champion choices in networked matches are unrestricted.

A three-second countdown starts each round. A round ends when every member of one team is dead. Teammates keep fighting when one falls. No resurrection, no respawn during a round.

## Champions

Four fixed-kit champions now have twelve abilities each, preserving their baseline movement, damage reduction and sustain while adding class resources and signature mechanics. **Ember** builds Heat and brands; **Vanguard** earns Resolve and protects allies; **Luminary** allocates three Guiding Stars; **Fulcrum** controls positions around a placed Gravity Anchor.

The complete current kits, exact effects, cooldowns, and shared rules live in [`CLASS_ABILITIES.md`](CLASS_ABILITIES.md), generated from the kit definitions by `tools/class_reference.gd`. Keys **1–7** use the first bar; **Shift+1–5** use the second. Every ability has a 256px painted icon.

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

See [`CLASS_ABILITIES.md`](CLASS_ABILITIES.md). `scripts/kits.gd` and `scripts/class_mechanics.gd` are authoritative. Balance remains provisional pending human matches.

## Combat mechanics

**Health** caps at 100. Damage is clamped to remaining health.

**Global cooldown (GCD)** — 1.5 seconds. Abilities with `off: true` bypass it. **No ability can be used while another cast is in progress**, even off-GCD ones.

**Cancelling a cast before it goes off clears the GCD.** The GCD is charged when the cast begins, so without this you paid for a spell that never happened. Cancelling is a real option, not a punishment. The ability still does not start its own cooldown.

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

**Control diminishing returns** — stuns, disorients, and roots share one DR category:

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

A / D **strafe** rather than turn — a deliberate divergence from the WoW default, where A / D turn and Q / E strafe. Turning moved to Q / E, which keeps keyboard turning available; mouse steering is unchanged and remains the primary way to turn.

| Input | Action |
| --- | --- |
| W / S | Forward / backward |
| A / D | Strafe |
| Q / E | Turn; strafe while holding RMB |
| Space | Jump |
| Hold RMB | Steer character and camera |
| Hold LMB | Orbit camera independently |
| Hold both mouse buttons | Run forward |
| F11 or Alt+Enter | Toggle fullscreen / windowed |
| 1–7 / Shift+1–5 (rebindable) | Hotbar slots. Keys and slot contents are set in Edit HUD. |

## Buffs and debuffs

Every effect is shown as a chip on the unit frame and again on the overhead nameplate, with its own countdown, and hovering a chip explains what it does. Stun, spell lockout, the damage-reduction shield, Grace, and diminishing-return stacks are all covered.

**Your own effects appear in one place, not three.** A personal buff and debuff strip sits top right, MMO-style, and the centre-screen readout covers crowd control. Your own nameplate deliberately shows neither — it would be repeating what you are already looking at. Allies and enemies still carry theirs overhead, because that is the only place you can read them.

Both the personal strip and the crowd control readout can be repositioned in Edit HUD.

Overhead nameplates show the same icons and timers as the unit frames, rather than a second, different way of saying it. The nameplate health bar is backed in red for enemies, matching the frame borders.

Each chip shows **the icon of the ability that caused the effect** — an Ember stun and a Vanguard stun are told apart at a glance — with the countdown beside it. Effects with no illustrated source, such as diminishing returns, fall back to their name so a chip is never blank.

**Auras are derived, never stored.** `scripts/auras.gd` reads the timers the simulation already keeps (`stunned`, `locked`, `shield`, `sprint`, `dr_timer`) rather than maintaining a second list. A displayed aura therefore cannot disagree with the simulation, and nothing extra has to be replicated. The shield field is one mechanic with four names — Ward, Iron Skin, Umbra, Sanctuary — chosen by the champion carrying it.

Diminishing returns is surfaced as an aura even though it is not an effect on the fighter, because it decides whether your next stun is worth casting.

## Crowd control on the action bars

Held slots also **grey out**, so a bar you cannot use looks unusable rather than merely busy.

A stun or a lockout sweeps the slots it prevents, exactly like a cooldown, so the bar always answers "when can I press this". Whichever wait is **longer** owns the slot — a 16 s cooldown outlives a 2 s stun, and a 4 s lockout outlives a spell that is already ready.

The lockout sweep mirrors the exemptions the simulation already applies: Vanguard ignores spell lockout, and defensive or movement abilities still work through it, so those slots stay clear.

## Crowd control tracker

When **you** are controlled, the centre of the screen shows the icon of the ability holding you, a radial timer over it, and what kind of control it is — `STUNNED`, `LOCKED OUT`. It sits above centre so it does not cover your own champion, and reuses the hotbar's radial sweep rather than a second renderer.

A stun outranks a lockout when both are running: a stun stops everything, a lockout only stops most of it, so the stun is the one you are actually waiting out.

The original duration is not replicated, so the tracker uses the highest value it has seen for the current effect as the sweep total. A refreshed or re-applied effect raises that peak, which is exactly when the sweep should restart.

## Edit HUD

Settings → **Edit HUD**, WoW's Edit Mode in miniature:

- Drag any frame — player, target, focus, party, enemies, hotbar — to move it. Positions are clamped on screen so nothing can be lost off an edge.
- Click a hotbar slot to rebind its key. A key already in use is **swapped**, not duplicated, so no key ever fires two abilities.
- Drag one hotbar slot onto another to swap which abilities sit where.
- **Reset layout** restores the defaults, frame positions included.

**Bindings carry modifiers.** `1`, `Shift+1`, `Alt+1` and `Ctrl+1` are four separate bindings on four separate slots. A modifier pressed alone is ignored, so holding Shift while reaching for a key does not bind Shift itself.

**Slot size is typed in Settings**, applies to every bar at once, and is clamped rather than trusted. Slots default to 55 px — 40% smaller than the original 92 — and the extra bars now match the first rather than being arbitrarily smaller.

**Everything a player changes is remembered**: HUD positions, keybinds, ability assignment, slot size and camera distance, all in `user://starfall.cfg`. Camera zoom is written on a short delay rather than on every wheel tick, and everything is flushed again when the window closes.

**Tests never load that file.** Launching with `--script` skips it, because otherwise whoever ran the game last decides what the suites see — an emptied slot 0 silently breaks every hotbar and combat assertion with nothing pointing at the cause.

**Shift + drag rearranges the bars at any time**, in a match or in the world, without opening Edit HUD. Empty slots on the other bars appear the moment a drag starts, so there is somewhere to drop, and disappear again when it ends. Each bar has a grip handle on its left, shown in Edit HUD, because the only draggable pixels were otherwise the few between buttons.

**Three action bars.** Twelve abilities occupy the first two bars; the third starts empty. Edit HUD supports moving, rebinding, and duplicating assignments. Saved seven-ability layouts gain missing abilities in empty slots automatically.

## Class colours

Each champion has a colour, defined once in `Kits.COLORS`:

| Champion | Colour |
| --- | --- |
| Ember | Orange `#ff8a4c` |
| Vanguard | Gold `#ffd166` |
| Luminary | Green `#7ee08a` |
| Fulcrum | Violet `#b98cff` |

Health bars everywhere — your own frame, allies, enemies, and the overhead nameplate bars — are **filled** with the class colour and **bordered** with the team colour, so reading which champion you are looking at never costs you friend-or-foe. Enemies get a heavier, hotter red border than the blue on allies.

The border is drawn as an overlay **on top of** the fill, not behind it. Behind, it only appeared on the empty part of the bar and vanished entirely at full health — which is exactly when you most need to know what you are looking at.

Party and enemy rows are real bars too, filled to current health, with the same colour rules.

Edit HUD works from the main menu with no match running: it shows placeholder frames and a full hotbar, the way WoW's Edit Mode does, because otherwise there is nothing on screen to arrange.

Saved frame positions are keyed by **stable names** (`PlayerFrame`, `Hotbar`, …). Godot's generated names shift when node creation order changes, which would silently apply a saved position to the wrong frame after an unrelated UI edit.

All of it is client-side presentation. The bar position a player chooses is translated to a kit index before anything reaches the simulation, so the server neither knows nor cares. Saved to `user://starfall.cfg` alongside display settings; a corrupt or malformed file falls back to defaults rather than producing a broken client — a saved assignment with a duplicate or out-of-range entry is rejected whole rather than half-applied.

## Display settings

Settings offers windowed, borderless fullscreen and exclusive fullscreen, plus a resolution picker filtered to what the monitor can actually show. Resolution is disabled in the fullscreen modes rather than hidden, so it is clear why it does not apply.
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
