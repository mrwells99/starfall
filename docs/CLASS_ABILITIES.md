# Class abilities

Current local implementation, September 11, 2026. Six selectable classes include the new **Null** kit below. The five established classes retain their abilities, including **Trinket on Ctrl+1**. Outlaw adds **Boot Kick on Shift+6**; Defense Detonation remains Shift+2 and Lasso Shift+5. Its retired Aim Test slot stays empty. Fulcrum's removed Horizon and direct Anchor slots stay empty; Gravity Anchor, Starfall and Entropy retain Shift+1, Shift+6 and Shift+7. All available abilities can be moved or rebound in Edit HUD.

Older saved layouts gain missing abilities in empty slots, or replace a duplicate slot if the bars are full. Existing primary, secondary, and action bindings take priority. Entropy receives Shift+7 and Trinket receives Ctrl+1 only when the respective key is free; otherwise its migrated slot remains clickable and can be rebound in Settings. A custom binding already attached to that slot is retained.

Range is the actual maximum distance to the selected target. Self-targeted abilities show their stored 0m range; their effect radii, anchor limits, or movement distances are listed separately. Cast times below are the ordinary values; the effect descriptions explain temporary instant-cast buffs. Outlaw's provisional cooldowns and unspecified tuning are documented in OUTLAW_CLASS.md.

## Null

| Default key | Ability | Current behavior | Range | Cooldown |
| --- | --- | --- | --- | --- |
| 1 | Stab | Instant filler; 12 damage. | 3 m | None; normal GCD |
| 2 | Backstab | Instant 35 damage; requires the rear 120° of the target. Invalid attempts spend nothing. | 3 m | **30 s** |
| 3 | Kick | Interrupt and 4-second spell lockout. Off GCD. | 3 m | 12 s |
| 4 | Nerve Lock | Instant melee stun for **4 seconds**. | 3 m | 20 s |
| 5 | Stealth | Concealment with proximity detection; details below. Off GCD. | Self | **None** |
| 6 | Haste | **50% movement speed for 6 seconds**. Off GCD. | Self | **25 s** |
| 7 | Blindside | Instantly teleport 1.2 m behind the target and face their direction. **Off GCD.** Requires a clear route and safe landing. | 18 m | 15 s |
| Shift+1 | Vantage Point | Rise vertically for **0.5 seconds**, then dive with both blades. Contact deals 22 damage and a **4-second stun/knockdown**. Brief recovery; no rebound or backflip. | 18 m | 25 s |
| Ctrl+1 | Trinket | Shared stun break. | Self | 120 s |

All buttons can be moved and rebound through the existing class-specific controls. The user's explicit timings and percentages are preserved. Damage values, ranges, Backstab's rear angle, Kick/Nerve Lock/Blindside/Vantage cooldowns, and auxiliary off-GCD choices are **initial tuning**, not additional user-approved balance decisions. Existing stun diminishing returns, immunities, and Trinket apply; four seconds is the full first stun.

Vantage rises at 10 m/s for 0.5 seconds, then tracks its target at 25 m/s until contact. A swept movement capsule prevents crossing terrain. Death, control, lost target or blocked movement cancels the move. Recovery lasts 0.18 seconds, followed by normal ground/air movement. Damage occurs once on server-confirmed contact. The victim uses a shortened knockdown transition with no Outlaw rebound or long recovery. Motion reference: the jump/dive near 12 seconds in [Death From Above animation](https://www.youtube.com/watch?v=6dBBNWlKVg8).

Full Stealth rules, source assets and verification: [NULL_CLASS.md](NULL_CLASS.md).

## Ember

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Kindle | Deal 16 damage. Gain 20 Heat and add a brand (up to 3) for 10s. | 18.0 m | 1.5s | 0.0s |
| 2 | Flashpoint | Consume your brands: 12 + 6 damage per brand. Three brands also deal 10 splash damage within 5m. Gain 10 Heat. | 16.5 m | Instant | 7.0s |
| 3 | Disrupt | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | 16.5 m | Instant | 12.0s (off GCD) |
| 4 | Stasis | Stun an enemy for up to 4.0 seconds, stopping movement and casting. | 15.0 m | 0.8s | 16.0s |
| 5 | Ward | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 16.0s |
| 7 | Blink | Blink up to 8.0m in your movement-input direction, including diagonals. With no movement input, blink forward along your camera's heading. Two charges; restores one charge every 14.0s. Stops at solid terrain. Off the global cooldown; usable while casting without interrupting the cast. | Self (0.0 m) | Instant | 14.0s (off GCD) |
| Shift+1 | Supernova | Requires 40 Heat. Consume all Heat: 18 + 0.4 damage per Heat to enemies within 5m of the target. | 18.0 m | 2.2s | 20.0s |
| Shift+2 | Solar Flare | Aim a 4m, 108-degree cone in front of you. No selected target is needed. Incapacitate enemies you hit for up to 3s. Terrain blocks the effect. Any damage breaks it; uses incapacitate diminishing returns. | 4 m cone | Instant | 18.0s |
| Shift+3 | Cinderstep | Requires and spends 20 Heat. Dash 6m and leave a 5s burning trail that slows enemies by 45%. | Self (0.0 m) | Instant | 18.0s (off GCD) |
| Shift+4 | Stoke | Generate 30 Heat. Maximum 100 Heat. | Self (0.0 m) | 1.5s | 12.0s |
| Shift+5 | Burning Wake | Create a 5m burning field at your feet for 5s. It slows enemies by 45% and deals 4 damage each second. | Self (0.0 m) | Instant | 18.0s |
| Ctrl+1 | Trinket | Instantly break your current stun. Does not remove other control or reset stun diminishing returns. | Self | Instant | 120s (off GCD) |

## Vanguard

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Sundering Blow | Deal 13 damage and gain 20 Resolve (maximum 100). Expose this enemy to your next Oathbreaker for 6s. | 2.5 m | Instant | 0.0s |
| 2 | Oathbreaker | Spend all Resolve: deal 15 + 0.3 damage per Resolve, plus 8 against your exposed target. | 2.5 m | 0.8s | 7.0s |
| 3 | Pummel | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | 3.0 m | Instant | 12.0s (off GCD) |
| 4 | Bash | Stun an enemy for up to 3.0 seconds, stopping movement and casting. | 2.5 m | Instant | 16.0s |
| 5 | Iron Skin | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 16.0s |
| 7 | Charge | Immediately root an enemy for up to 1.5s, then rush along a safe route at 32m/s and deal 6.0 damage on arrival. Line of sight is required only when casting. Uses root diminishing returns. | 16.5 m | Instant | 12.0s (off GCD) |
| Shift+1 | Intercede | Rush to another ally. For 5s redirect 30% of their damage to yourself, up to 30 total, while within 18m and line of sight. Redirected damage grants Resolve. | 16.5 m | Instant | 18.0s (off GCD) |
| Shift+2 | Hold the Line | For 4s, stand still and take 70% less frontal damage; resist displacement. Turning is allowed. Attacking ends this stance. Does not stack with stronger reduction. | Self (0.0 m) | Instant | 20.0s (off GCD) |
| Shift+3 | Challenge | For 6s, this enemy attacking your allies grants you 15 Resolve per hit, at most once per second. | 16.5 m | Instant | 16.0s |
| Shift+4 | Earthsplitter | Deal 12 damage and stun enemies in a narrow 8m forward line for up to 1s. Shares stun diminishing returns. | 6.0 m | 0.7s | 18.0s |
| Shift+5 | Unbroken | Spend 40 Resolve to gain 4s of 60% damage reduction. | Self (0.0 m) | Instant | 20.0s (off GCD) |
| Ctrl+1 | Trinket | Instantly break your current stun. Does not remove other control or reset stun diminishing returns. | Self | Instant | 120s (off GCD) |

## Luminary

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Smite | Deal 10.0 damage to an enemy. | 18.0 m | 1.5s | 0.0s |
| 2 | Falling Star | Heal 18. Consume one of your stars on the target to heal 16 more. | 18.0 m | Instant | 7.0s |
| 3 | Absolution | Remove stun, root and slow. Consume one of your stars to grant 3s immunity to roots and slows. | 18.0 m | Instant | 10.0s (off GCD) |
| 4 | Rebuke | Stun an enemy for up to 3.0 seconds, stopping movement and casting. | 15.0 m | 1.0s | 18.0s |
| 5 | Sanctuary | An ally or you takes 60% less damage for 5.0 seconds. | 18.0 m | Instant | 22.0s (off GCD) |
| 6 | Stitchlight | Heal 27. A starred target echoes 9 healing to one other starred ally within 18m and line of sight. | 18.0 m | 1.8s | 0.0s |
| 7 | Grace | Move 65% faster for 4.0 seconds. | Self (0.0 m) | Instant | 16.0s (off GCD) |
| Shift+1 | Guiding Star | Place a star on an ally or yourself for 30s. Maximum 3 total per Luminary; placing a fourth moves your oldest star. | 18.0 m | Instant | 0.0s |
| Shift+2 | Pilgrim's Step | Consume your star on another ally to rush toward them. Stops at terrain. | 16.5 m | Instant | 16.0s (off GCD) |
| Shift+3 | Last Light | For 4s, the first lethal hit leaves the ally at 1 HP and consumes this protection. Further damage can kill. | 18.0 m | Instant | 45.0s (off GCD) |
| Shift+4 | Mend | Restore up to 28.0 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 16.0s |
| Shift+5 | Starfall | Deal 16 damage and heal each of your starred allies for 8 per star within 18m and line of sight. | 18.0 m | 1.5s | 12.0s |
| Ctrl+1 | Trinket | Instantly break your current stun. Does not remove other control or reset stun diminishing returns. | Self | Instant | 120s (off GCD) |

## Fulcrum

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Graviton | Deal 6 damage and apply an 11s DoT: 3 damage each second per stack, up to 2 stacks per caster. Reapplying refreshes both stacks without delaying the next tick. Generates no Meditation. A landed Collapse grants a 4s buff for one instant Graviton, consumed on use. | 18.0 m | 1.3s | 0.0s |
| 2 | Inward | Pull an enemy up to 8m toward your anchor. Target must be within 9m of the anchor (1.5 times Heavy Orbit's radius); caster and anchor must remain within 18m. Moving the enemy cancels their current cast without a spell lockout. Grants a 4s buff for one instant, off-global-cooldown Collapse, consumed on use; its own cooldown still applies. Works through line-of-sight blockers; movement stops at solid terrain. | 18.0 m | Instant | 9.0s |
| 5 | Umbra | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 16.0s |
| 7 | Tether | Drag your target up to 8.0 meters toward you. Works on an enemy or an ally. | 16.5 m | Instant | 14.0s (off GCD) |
| Shift+1 | Gravity Anchor | Place a visible gravity anchor on the ground up to 10m ahead, stopping before walls. Lasts 20s. Replacing it ends its orbit. | Self (0.0 m) | 0.6s | 4.0s |
| Shift+2 | Outward | Push an enemy up to 8m away from your anchor. Target must be within 9m of the anchor (1.5 times Heavy Orbit's radius); caster and anchor must remain within 18m. Moving the enemy cancels their current cast without a spell lockout. Works through line-of-sight blockers; movement stops at solid terrain. | 18.0 m | Instant | 9.0s |
| Shift+3 | Heavy Orbit | Your anchor creates a 6m slowing field for 6s, even through line-of-sight blockers. Enemies inside move 45% slower. | Self (0.0 m) | Instant | 16.0s |
| Shift+4 | Counterweight | Exchange positions with another ally. Both routes must be clear; cannot cross terrain. | 16.5 m | Instant | 22.0s (off GCD) |
| Shift+5 | Collapse | Consume your anchor: deal 22 damage within 6m and root for up to 2s. At 75+ Meditation, stun for up to 3s instead; Meditation is not spent. Inward grants a 4s buff for one instant Collapse off the global cooldown, consumed on use. Its own cooldown still applies. Hitting an enemy grants a 4s buff for one instant Graviton, consumed on use. Works through line-of-sight blockers. Root and stun use separate diminishing returns. | Self (0.0 m) | 1.5s | 18.0s |
| Shift+6 | Starfall | Requires at least 50 Meditation. After a 2s cast, spend all Meditation to deal 20 + 0.4 damage per Meditation (40–60) to enemies within 5m of the target. Interrupted casts spend nothing. | 18.0 m | 2.0s | 12.0s |
| Shift+7 | Entropy | Instantly apply a 15s DoT: 2 damage and 5 Meditation each second. One stack per caster; reapplying refreshes without delaying the next tick. Meditation caps at 100. | 18.0 m | Instant | 0.0s |
| Ctrl+1 | Trinket | Instantly break your current stun. Does not remove other control or reset stun diminishing returns. | Self | Instant | 120s (off GCD) |

## Outlaw

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Starshot | Fire for 8 damage. Unkickable; cast while moving 30% slower. | 18m | 0.7s | 0s |
| 2 | Severe | Slash for 20% current health. Bleed for 2 damage each second for 5s and slow by 60% for 6s. Unkickable; cast while moving. Instant for 1.5s after Roll. | 3.3m | 0.6s | 4s |
| 3 | Trickshot | Deal 18 damage during airborne Backflip or a flying Coin Toss. Coin shots ricochet around cover through clear paths. One use per combo; a hit grants 1 Defense Detonation stack (max 3). | 18m | Instant | 0s (off GCD) |
| 4 | Backflip | Leap backward; usable while jumping. While airborne: 50% less damage, CC immunity, and one Trickshot opportunity. Ends on landing. | Self | Instant | 12s (off GCD) |
| 5 | Ward | Take 60% less damage for 5.0 seconds. | Self | Instant | 22s (off GCD) |
| 6 | Mend | Heal 28 health and remove attached bleeds and damage-over-time effects. | Self | 2s | 16s |
| 7 | Roll | Roll 7.8m in your movement direction; camera-forward if stationary. Gain 25% move speed for 5s and one instant Severe for 1.5s on completion, even against a wall. | Self | Instant | 10s (off GCD) |
| Shift+1 | Coin Toss | Throw a coin for up to 1.8s, carrying your momentum. Trickshot can ricochet from it around cover. Terrain or a successful shot ends the combo. | Self | Instant | 14s |
| Shift+2 | Defense Detonation | Aim over your shoulder. Left-click spends all stacks (1–3), firing every 0.13s for 10% maximum health per hit. Misses spend stacks. Firing uses GCD; last shot exits aim. Press again to cancel. | Self | Instant | 0s (off GCD) |
| Shift+3 | Deadeye | Mark all enemies. Walk during an unkickable 3s cast; hit those within 18m and clear sight at completion for 40% maximum health. Cannot jump. Interrupted casts refund cooldown. | 18m sight at completion | 3s | 90s |
| Shift+5 | Lasso | Unkickable moving cast: lasso into a dropkick, stun during travel, then knock back and knock down for 1.5s. Rebound; gain 1 Defense Detonation stack. Usable during Backflip with slowed drift and CC immunity; landing cancels the cast. | 18m | 0.7s | 20s |
| Shift+6 | Boot Kick | Interrupt a cast within 3m and lock out spells for 4s. | 3m | Instant | 12s (off GCD) |
| Ctrl+1 | Trinket | Break your current stun instantly. Usable while stunned; 2-minute cooldown. | Self | Instant | 120s (off GCD) |

## Shared rules

Accepted world duels and 1v1 arenas automatically select and lock the opponent. Clicks, target cycling, party/focus shortcuts and Escape cannot switch or clear that selection; Escape can still open the menu. Hostile action targets are also pinned by the authority. Self/helpful abilities retain their normal self fallback. During a world duel, attacks cannot damage unrelated players or training dummies; free world selection resumes when the duel ends. 3v3 retains free targeting.

Each pillar now uses one flush collision column matching its outer base footprint from the floor to 32m. This fills the recessed collision lip and removes seams that could catch movement, Roll, Lasso or Charge. The visible stone remains unchanged; clients and servers use identical collision.

Aimed attacks use each character's animated body hitboxes expanded to **2× horizontal width/depth and 1.25× height**, around the character's feet. Movement capsules, anatomy, cloth/weapon exclusions and base hitbox rigs are unchanged. The camera preview and server rewind trace use the same expansion.

Trinket breaks the stun category only, including Lasso knockdown, instantly and off GCD. It works through stun, silence and spell lockout, but cannot be spent while unstunned or dead. Roots, slows, other control and stun diminishing returns remain. Its cooldown is 120s. Both client and server must run version 0.11.1 for this kit and aiming-volume update.

Base positive cast ranges are reduced by 25%, rounded to the nearest 0.5m, and capped at 18m. Severe then receives its explicit 10% increase from 3m to 3.3m, without another rounding pass. Opposing arena spawn lines are 20m apart, so direct targeted spells cannot reach the opposing spawn at the start. This does not prevent self abilities or change separately specified effect radii and displacement distances. Luminary healing links and Intercede's ongoing protection require allies within 18m and line of sight.

Heat, Resolve and Meditation cap at 100. Graviton deals 6 initial damage and applies an 11-second DoT, dealing 3 damage each second per stack with at most two stacks per caster. Reapplication refreshes both stacks without delaying the next tick. Graviton generates no Meditation. These are two damage-over-time stacks, not stored casts.

Entropy is an instant 15-second DoT that deals 2 damage and generates 5 Meditation for its caster each second. Each caster can maintain only one Entropy stack on a target; reapplication refreshes its duration without delaying the next tick. Graviton and Entropy can coexist. Completed DPS Mend clears all attached DoTs; standing in a ground hazard still deals damage. DoTs stop when their caster dies, departs, or can no longer harm the target.

Inward grants a four-second buff for one instant, off-global-cooldown Collapse. A landed Collapse grants a separate four-second buff for one instant Graviton. Each buff disappears when used or when its window expires; another qualifying cast refreshes the window to four seconds without stacking. Failed cast attempts neither consume nor refresh the remaining time. Collapse's own 18-second cooldown still applies, and its instant cast does not restart the global cooldown. Instant Graviton retains its normal global cooldown. At 75+ Meditation, Collapse stuns for up to 3 seconds without spending Meditation.

Vanguard's Charge immediately applies a 1.5-second root on a successful cast, subject to root immunity and diminishing returns. It then moves continuously at 32m/s along a collision-checked route and deals its existing 6 damage on arrival at melee range. Range, facing and LOS are checked initially; losing LOS afterwards does not cancel the rush. Detours use ramp entrances and avoid pillars, walls and terrace ledges. A target with no safe route is rejected before spending the cast. Target death or loss of duel permission cancels remaining travel/damage. The individual 12-second cooldown and off-GCD behavior are unchanged.

Fulcrum's Starfall requires at least 50 Meditation and consumes all Meditation only on successful cast completion. It deals 20 + 0.4 damage per point spent to hostile targets within 5m of the selected target's position at completion, including the selected target. Splash requires line of sight from the impact center. Interrupted casts spend no Meditation. Luminary's Starfall retains its separate damage and starred-ally healing effect.

Each Luminary owns at most three stars. Brands, stars, anchors, defensive states, roots and ground fields are authoritative and replicated. Class resources reset between rounds and at duel boundaries. Stars expire after 30 seconds; brands after 10.

Gravity Anchor is placed up to 10m in the direction faced, swept against terrain and projected onto the floor. It lasts 20 seconds. Anchor abilities need the caster within 18m of the anchor. Inward and Outward need their target within 9m of the anchor (1.5 times Heavy Orbit's 6m radius), while retaining their existing 18m caster-to-target limit. Actual displacement by either ability immediately cancels the enemy's current cast without school lockout or GCD refund. Zero movement does not interrupt. Horizon and the direct Anchor stun are no longer available; Gravity Anchor remains. Inward, Outward, Collapse and Heavy Orbit ignore line-of-sight blockers; pushes and pulls still stop at solid collision. Non-anchor ground effects still require line of sight. Counterweight exchanges immediately after validation; both swept routes must be clear.

Solar Flare is an untargeted 4m cone with a 108-degree total angle, aimed using Ember's character heading. Its local ground outline appears only for one second after a successful cast, including a cast that hits no enemies. Enemies inside the cone must also pass terrain line-of-sight and duel-permission checks. It retains its 18s cooldown, ordinary global cooldown and up-to-3s incapacitate, which breaks on damage.

Blink has two stored casts, restoring one charge at a time every 14s. Spending the second charge does not restart the first recharge. It moves up to 8m along the movement input sampled when casting, including diagonals; with no movement input it uses camera heading, even during free look or airborne momentum. It is off the global cooldown and stops at solid terrain. The hotbar shows remaining charges and a recharge countdown; one available charge stays usable while the other recharges.

Control categories have independent diminishing returns. Rooted characters can cast but cannot jump or start movement abilities; Absolution clears roots and slows. An already accepted Charge completes its committed travel. Hold the Line prevents movement and displacement but allows turning; attacking ends it. Damage reductions use the strongest applicable reduction, not multiplication.

Last Light prevents one lethal hit by leaving 1 HP; it is not a resurrection. Intercede redirects at most 30 raw damage, requires ongoing range and line of sight, and cannot form recursive damage chains. Mend always heals up to 28, without dampening. Other healing retains match dampening in arena matches only; world healing is never dampened.

World bystanders cannot damage, control, or displace duelists, or heal/protect/exchange places with them. Self abilities remain available. Bot priorities exercise each identity; they are introductory sparring AI, not a competitive benchmark.

Anchor rings and timers, burning-field outlines, Supernova warnings, resource text, brand counts, star counts, and status icons expose combat state. Instant Collapse and instant Graviton show buff countdowns and highlight their hotbar icons only while the four-second windows remain active. Earthsplitter applies a brief stun with a small airborne launch.
