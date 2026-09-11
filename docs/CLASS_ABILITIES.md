# Class abilities

Current implementation, September 10, 2026. Outlaw has eleven available abilities: Defense Detonation on Shift+2 owns shoulder aiming and fires an aimed burst on left-click; Lasso is on Shift+5. The separate Aim Test entry is retired and its old Shift+4 slot is empty. Fulcrum has twelve available abilities: Horizon and the direct Anchor stun are removed, with their old default key 3 and 4 slots left empty to preserve all other saved bindings. Gravity Anchor remains on Shift+1, Starfall on Shift+6 and Entropy on Shift+7. Ember, Vanguard and Luminary have twelve abilities, ending at Shift+5. All available slots can be rebound or moved in Edit HUD.

Older saved layouts gain missing abilities in empty slots, or replace a duplicate slot if the bars are full. Existing primary, secondary, and action bindings take priority. Entropy receives Shift+7 only when that key is free; otherwise its migrated slot remains clickable and can be rebound in Settings. A custom binding already attached to that slot is retained.

Range is the actual maximum distance to the selected target. Self-targeted abilities show their stored 0m range; their effect radii, anchor limits, or movement distances are listed separately. Cast times below are the ordinary values; the effect descriptions explain temporary instant-cast buffs. Outlaw's provisional cooldowns and unspecified tuning are documented in OUTLAW_CLASS.md.

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

## Outlaw

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Starshot | Cast while moving at 70% of your normal movement speed. Kicks cannot interrupt this cast or apply a lockout. Transmute starlight into a gunshot for 8 damage. Hard crowd control can still cancel it; range and line of sight are checked when it finishes. | 18.0 m | 0.7s | 0.0s |
| 2 | Severe | Cast while moving normally; kicks cannot interrupt this cast or apply a lockout. Slash with your Bowie knife for 15% of the enemy's current health, rounded to a whole number. Apply a 5s bleed dealing 2 damage each second. One bleed per caster; reapplication refreshes it. Completing Roll grants a 1.5s buff for one instant Severe; its own cooldown and global cooldown still apply. | 3.3 m | 0.6s | 4.0s |
| 3 | Trickshot | Instant, off-global-cooldown gunshot for 12 damage. Only usable once during Backflip's airborne combo or while your Coin Toss is still in flight. A coin shot ricochets from the coin to your selected enemy, requiring clear paths to the coin and from the coin to the enemy. A landed combo grants one Defense Detonation stack, up to 3. | 18.0 m | Instant | 0.0s (off GCD) |
| 4 | Backflip | Leap backward about 8.6m with a 2.8m rise on level ground, stopping at terrain. Deals no damage. While airborne, become immune to crowd control and forced movement and gain one opportunity to cast Trickshot. The combo window and immunity end when you land. Off the global cooldown. | Self (0.0 m) | Instant | 12.0s (off GCD) |
| 5 | Ward | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 16.0s |
| 7 | Roll | Roll up to 7.8m over approximately 0.48s in your movement-input direction, including diagonals; with no movement input, roll along camera heading. Stops at terrain. Completing the roll grants a 1.5s buff for one instant Severe. Off the global cooldown. | Self (0.0 m) | Instant | 10.0s (off GCD) |
| Shift+1 | Coin Toss | Toss a visible coin along camera heading in a 1.8s arc, adding your movement velocity at release so a forward throw stays ahead while running. While it remains airborne, Trickshot can shoot it and ricochet into an enemy behind your own line-of-sight cover. Both bullet paths must be clear; the coin stops at solid terrain. Tossing alone deals no damage or resource gain. | Self (0.0 m) | Instant | 14.0s |
| Shift+2 | Defense Detonation | Raise your gun and aim over your right shoulder. Left-click to spend all available stacks (1 to 3) and fire an aimed burst, 0.13s between shots. Each shot traces the center crosshair for 18m and deals 10% maximum health on a body hit; misses still spend their stack. Move and adjust aim between shots with light recoil. No cast time; firing uses the global cooldown. Aiming ends after the last shot. Use this ability again to leave without firing. | Self (0.0 m) | Instant | 0.0s (off GCD) |
| Shift+3 | Deadeye | Automatically mark every enemy without selecting a target. Wind up for 3s while limited to walking, then hit marked enemies still within 18m and clear line of sight for 40% of their maximum health. Cover is checked at completion. Kicks cannot interrupt it or apply a lockout. Cannot jump during the windup. 90s cooldown, refunded if the cast is interrupted or cancelled before completion. | 18 m sight at completion | 3.0s | 90.0s |
| Shift+5 | Lasso | Swing a celestial lasso during a 0.7s mobile, unkickable cast. The rope flies to the target, then pulls you into a dropkick, stunning them during your approach. Knock them back up to 3m and down for 1.5s; rebound 2m away in approximately 0.44s. Stun diminishing returns apply once to the combo. Landing the dropkick grants one Defense Detonation stack. During Backflip, backward drift slows to 25% and descent slows through windup and rope flight. Failure restores normal airborne momentum; landing before cast completion cancels it. The airborne Lasso combo retains immunity to crowd control and displacement. Terrain stops travel. Deals no damage. | 18.0 m | 0.7s | 20.0s |

## Shared rules

Accepted world duels and 1v1 arenas automatically select and lock the opponent. Clicks, target cycling, party/focus shortcuts and Escape cannot switch or clear that selection; Escape can still open the menu. Hostile action targets are also pinned by the authority. Self/helpful abilities retain their normal self fallback. During a world duel, attacks cannot damage unrelated players or training dummies; free world selection resumes when the duel ends. 3v3 retains free targeting.

The four pillar collision columns extend invisibly to 32m above the arena floor, preventing players from reaching or standing on pillar tops. The visible pillar models are unchanged. The same collision applies on clients and dedicated servers.

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
