# Class abilities

Current implementation, September 8, 2026. Balance is provisional and needs human playtesting. Fulcrum has fourteen abilities: 1–7 on the first bar and Shift+1–7 on the second, including Starfall on Shift+6 and Entropy on Shift+7. Other classes have twelve abilities, ending at Shift+5. All slots can be rebound or moved in Edit HUD.

Older saved layouts gain missing abilities in empty slots, or replace a duplicate slot if the bars are full. Existing primary, secondary, and action bindings take priority. Entropy receives Shift+7 only when that key is free; otherwise its migrated slot remains clickable and can be rebound in Settings. A custom binding already attached to that slot is retained.

Range is the actual maximum distance to the selected target. Self-targeted abilities show their stored 0m range; their effect radii, anchor limits, or movement distances are listed separately. Cast times below are the ordinary values; the effect descriptions explain instant-cast charges.

## Ember

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Kindle | Deal 16 damage. Gain 20 Heat and add a brand (up to 3) for 10s. | 18.0 m | 1.5s | 0.0s |
| 2 | Flashpoint | Consume your brands: 12 + 6 damage per brand. Three brands also deal 10 splash damage within 5m. Gain 10 Heat. | 16.5 m | Instant | 7.0s |
| 3 | Disrupt | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | 16.5 m | Instant | 12.0s (off GCD) |
| 4 | Stasis | Stun an enemy for up to 4.0 seconds, stopping movement and casting. | 15.0 m | 0.8s | 16.0s |
| 5 | Ward | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 16.0s |
| 7 | Blink | Move up to 8.0 meters in the direction you face. | Self (0.0 m) | Instant | 14.0s (off GCD) |
| Shift+1 | Supernova | Requires 40 Heat. Consume all Heat: 18 + 0.4 damage per Heat to enemies within 5m of the target. | 18.0 m | 2.2s | 20.0s |
| Shift+2 | Solar Flare | Disorient enemies in your forward 8m cone for up to 3s. Damage breaks it; shares stun diminishing returns. | 6.0 m | Instant | 18.0s |
| Shift+3 | Cinderstep | Requires and spends 20 Heat. Dash 6m and leave a 5s burning trail that slows enemies by 45%. | Self (0.0 m) | Instant | 18.0s (off GCD) |
| Shift+4 | Stoke | Generate 30 Heat. Maximum 100 Heat. | Self (0.0 m) | 1.5s | 12.0s |
| Shift+5 | Burning Wake | Create a 5m burning field at your feet for 5s. It slows enemies by 45% and deals 4 damage each second. | Self (0.0 m) | Instant | 18.0s |

## Vanguard

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Sundering Blow | Deal 13 damage and gain 20 Resolve (maximum 100). Expose this enemy to your next Oathbreaker for 6s. | 2.5 m | Instant | 0.0s |
| 2 | Oathbreaker | Spend all Resolve: deal 15 + 0.3 damage per Resolve, plus 8 against your exposed target. | 2.5 m | 0.8s | 7.0s |
| 3 | Pummel | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | 3.0 m | Instant | 12.0s (off GCD) |
| 4 | Bash | Stun an enemy for up to 3.0 seconds, stopping movement and casting. | 2.5 m | Instant | 16.0s |
| 5 | Iron Skin | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 16.0s |
| 7 | Charge | Rush toward an enemy and deal 6.0 damage if you reach melee range. | 16.5 m | Instant | 12.0s (off GCD) |
| Shift+1 | Intercede | Rush to another ally. For 5s redirect 30% of their damage to yourself, up to 30 total, while within 18m and line of sight. Redirected damage grants Resolve. | 16.5 m | Instant | 18.0s (off GCD) |
| Shift+2 | Hold the Line | For 4s, stand still and take 70% less frontal damage; resist displacement. Turning is allowed. Attacking ends this stance. Does not stack with stronger reduction. | Self (0.0 m) | Instant | 20.0s (off GCD) |
| Shift+3 | Challenge | For 6s, this enemy attacking your allies grants you 15 Resolve per hit, at most once per second. | 16.5 m | Instant | 16.0s |
| Shift+4 | Earthsplitter | Deal 12 damage and stun enemies in a narrow 8m forward line for up to 1s. Shares stun diminishing returns. | 6.0 m | 0.7s | 18.0s |
| Shift+5 | Unbroken | Spend 40 Resolve to gain 4s of 60% damage reduction. | Self (0.0 m) | Instant | 20.0s (off GCD) |

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

## Fulcrum

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Graviton | Deal 6 damage and apply an 11s DoT: 3 damage each second per stack, up to 2 stacks per caster. Reapplying refreshes both stacks without delaying the next tick. Generates no Meditation. Collapse hits make your next Graviton instant. | 18.0 m | 1.3s | 0.0s |
| 2 | Inward | Pull an enemy up to 8m toward your anchor. Requires an active anchor within 18m. Grants one instant, off-global-cooldown Collapse; its own cooldown still applies. Works through line-of-sight blockers; movement stops at solid terrain. | 18.0 m | Instant | 9.0s |
| 3 | Horizon | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | 16.5 m | Instant | 12.0s (off GCD) |
| 4 | Anchor | Stun an enemy for up to 3.5 seconds, stopping movement and casting. | 13.5 m | 0.6s | 16.0s |
| 5 | Umbra | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 16.0s |
| 7 | Tether | Drag your target up to 8.0 meters toward you. Works on an enemy or an ally. | 16.5 m | Instant | 14.0s (off GCD) |
| Shift+1 | Gravity Anchor | Place a visible gravity anchor on the ground up to 10m ahead, stopping before walls. Lasts 20s. Replacing it ends its orbit. | Self (0.0 m) | 0.6s | 4.0s |
| Shift+2 | Outward | Push an enemy up to 8m away from your anchor. Requires an active anchor within 18m. Works through line-of-sight blockers; movement still stops at solid terrain. | 18.0 m | Instant | 9.0s |
| Shift+3 | Heavy Orbit | Your anchor creates a 6m slowing field for 6s, even through line-of-sight blockers. Enemies inside move 45% slower. | Self (0.0 m) | Instant | 16.0s |
| Shift+4 | Counterweight | Exchange positions with another ally. Both routes must be clear; cannot cross terrain. | 16.5 m | Instant | 22.0s (off GCD) |
| Shift+5 | Collapse | Consume your anchor: deal 22 damage within 6m and root for up to 2s. At 75+ Meditation, stun for up to 3s instead; Meditation is not spent. Inward makes your next Collapse instant and off the global cooldown. Its own cooldown still applies. Hitting an enemy makes your next Graviton instant. Works through line-of-sight blockers. Control shares diminishing returns. | Self (0.0 m) | 1.5s | 18.0s |
| Shift+6 | Starfall | Requires at least 50 Meditation. After a 2s cast, spend all Meditation to deal 20 + 0.4 damage per Meditation (40–60) to enemies within 5m of the target. Interrupted casts spend nothing. | 18.0 m | 2.0s | 12.0s |
| Shift+7 | Entropy | Instantly apply a 15s DoT: 2 damage and 5 Meditation each second. One stack per caster; reapplying refreshes without delaying the next tick. Meditation caps at 100. | 18.0 m | Instant | 0.0s |

## Shared rules

All positive cast ranges are reduced by 25%, rounded to the nearest 0.5m, and capped at 18m. Opposing arena spawn lines are 20m apart, so direct targeted spells cannot reach the opposing spawn at the start. This does not prevent self abilities or change separately specified effect radii and displacement distances. Luminary healing links and Intercede's ongoing protection require allies within 18m and line of sight.

Heat, Resolve and Meditation cap at 100. Graviton deals 6 initial damage and applies an 11-second DoT, dealing 3 damage each second per stack with at most two stacks per caster. Reapplication refreshes both stacks without delaying the next tick. Graviton generates no Meditation. These are two damage-over-time stacks, not stored casts.

Entropy is an instant 15-second DoT that deals 2 damage and generates 5 Meditation for its caster each second. Each caster can maintain only one Entropy stack on a target; reapplication refreshes its duration without delaying the next tick. Graviton and Entropy can coexist. Completed DPS Mend clears all attached DoTs; standing in a ground hazard still deals damage. DoTs stop when their caster dies, departs, or can no longer harm the target.

Inward grants one stored instant, off-global-cooldown Collapse. Repeated Inward casts do not add another charge. The charge is retained until used, and Collapse's own 18-second cooldown still applies. Casting charged Collapse does not restart the global cooldown. A Collapse that hits an enemy grants one instant Graviton, also retained until used. At 75+ Meditation, Collapse stuns for up to 3 seconds (subject to diminishing returns) without spending Meditation.

Fulcrum's Starfall requires at least 50 Meditation and consumes all Meditation only on successful cast completion. It deals 20 + 0.4 damage per point spent to hostile targets within 5m of the selected target's position at completion, including the selected target. Splash requires line of sight from the impact center. Interrupted casts spend no Meditation. Luminary's Starfall retains its separate damage and starred-ally healing effect.

Each Luminary owns at most three stars. Brands, stars, anchors, defensive states, roots and ground fields are authoritative and replicated. Class resources reset between rounds and at duel boundaries. Stars expire after 30 seconds; brands after 10.

Gravity Anchor is placed up to 10m in the direction faced, swept against terrain and projected onto the floor. It lasts 20 seconds. Anchor abilities need the caster within 18m of the anchor. Inward and Outward additionally need their target within 18m of the anchor and within their 18m cast range. Inward, Outward, Collapse and Heavy Orbit ignore line-of-sight blockers; pushes and pulls still stop at solid collision. Non-anchor ground effects still require line of sight. Counterweight exchanges immediately after validation; both swept routes must be clear.

Stuns, disorients, and roots share diminishing returns. Solar Flare breaks on damage. Rooted characters can cast but cannot jump or use movement abilities; Absolution clears roots and slows. Hold the Line prevents movement and displacement but allows turning; attacking ends it. Damage reductions use the strongest applicable reduction, not multiplication.

Last Light prevents one lethal hit by leaving 1 HP; it is not a resurrection. Intercede redirects at most 30 raw damage, requires ongoing range and line of sight, and cannot form recursive damage chains. Mend always heals up to 28, without dampening. Other healing retains match dampening in arena matches only; world healing is never dampened.

World bystanders cannot damage, control, or displace duelists, or heal/protect/exchange places with them. Self abilities remain available. Bot priorities exercise each identity; they are introductory sparring AI, not a competitive benchmark.

Anchor rings and timers, burning-field outlines, Supernova warnings, resource text, brand counts, star counts, and status icons expose combat state. Charged Collapse and instant Graviton highlight their hotbar icons. Earthsplitter applies a brief stun with a small airborne launch. Exact character transformation animations, sound, and bespoke spell cinematics are not implemented by this class pass.
