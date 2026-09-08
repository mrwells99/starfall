# Class abilities

Current implementation, September 8, 2026. Balance is provisional and needs human playtesting. Each class has twelve abilities: 1–7 on the first bar and Shift+1–5 on the second. All slots can be rebound or moved in Edit HUD. Older layouts automatically gain missing abilities in empty slots.

## Ember

| Key | Ability | Effect | Cast | Cooldown |
| --- | --- | --- | --- | --- |
| 1 | Kindle | Deal 16 damage. Gain 20 Heat and add a brand (up to 3) for 10s. | 1.5s | 0.0s |
| 2 | Flashpoint | Consume your brands: 12 + 6 damage per brand. Three brands also deal 10 splash damage within 5m. Gain 10 Heat. | Instant | 7.0s |
| 3 | Disrupt | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | Instant | 12.0s (off GCD) |
| 4 | Stasis | Stun an enemy for up to 4.0 seconds, stopping movement and casting. | 0.8s | 16.0s |
| 5 | Ward | Take 60% less damage for 5.0 seconds. | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. | 2.0s | 16.0s |
| 7 | Blink | Move up to 8.0 meters in the direction you face. | Instant | 14.0s (off GCD) |
| Shift+1 | Supernova | Requires 40 Heat. Consume all Heat: 18 + 0.4 damage per Heat to enemies within 5m of the target. | 2.2s | 20.0s |
| Shift+2 | Solar Flare | Disorient enemies in your forward 8m cone for up to 3s. Damage breaks it; shares stun diminishing returns. | Instant | 18.0s |
| Shift+3 | Cinderstep | Requires and spends 20 Heat. Dash 6m and leave a 5s burning trail that slows enemies by 45%. | Instant | 18.0s (off GCD) |
| Shift+4 | Stoke | Generate 30 Heat. Maximum 100 Heat. | 1.5s | 12.0s |
| Shift+5 | Burning Wake | Create a 5m burning field at your feet for 5s. It slows enemies by 45% and deals 4 damage each second. | Instant | 18.0s |

## Vanguard

| Key | Ability | Effect | Cast | Cooldown |
| --- | --- | --- | --- | --- |
| 1 | Sundering Blow | Deal 13 damage and gain 20 Resolve (maximum 100). Expose this enemy to your next Oathbreaker for 6s. | Instant | 0.0s |
| 2 | Oathbreaker | Spend all Resolve: deal 15 + 0.3 damage per Resolve, plus 8 against your exposed target. | 0.8s | 7.0s |
| 3 | Pummel | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | Instant | 12.0s (off GCD) |
| 4 | Bash | Stun an enemy for up to 3.0 seconds, stopping movement and casting. | Instant | 16.0s |
| 5 | Iron Skin | Take 60% less damage for 5.0 seconds. | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. | 2.0s | 16.0s |
| 7 | Charge | Rush toward an enemy and deal 6.0 damage if you reach melee range. | Instant | 12.0s (off GCD) |
| Shift+1 | Intercede | Rush to another ally. For 5s redirect 30% of their damage to yourself, up to 30 total, while within 28m and line of sight. Redirected damage grants Resolve. | Instant | 18.0s (off GCD) |
| Shift+2 | Hold the Line | For 4s, stand still and take 70% less frontal damage; resist displacement. Turning is allowed. Attacking ends this stance. Does not stack with stronger reduction. | Instant | 20.0s (off GCD) |
| Shift+3 | Challenge | For 6s, this enemy attacking your allies grants you 15 Resolve per hit, at most once per second. | Instant | 16.0s |
| Shift+4 | Earthsplitter | Deal 12 damage and stun enemies in a narrow 8m forward line for up to 1s. Shares stun diminishing returns. | 0.7s | 18.0s |
| Shift+5 | Unbroken | Spend 40 Resolve to gain 4s of 60% damage reduction. | Instant | 20.0s (off GCD) |

## Luminary

| Key | Ability | Effect | Cast | Cooldown |
| --- | --- | --- | --- | --- |
| 1 | Smite | Deal 10.0 damage to an enemy. | 1.5s | 0.0s |
| 2 | Falling Star | Heal 18. Consume one of your stars on the target to heal 16 more. | Instant | 7.0s |
| 3 | Absolution | Remove stun, root and slow. Consume one of your stars to grant 3s immunity to roots and slows. | Instant | 10.0s (off GCD) |
| 4 | Rebuke | Stun an enemy for up to 3.0 seconds, stopping movement and casting. | 1.0s | 18.0s |
| 5 | Sanctuary | An ally or you takes 60% less damage for 5.0 seconds. | Instant | 22.0s (off GCD) |
| 6 | Stitchlight | Heal 27. A starred target echoes 9 healing to one other starred ally within 28m and line of sight. | 1.8s | 0.0s |
| 7 | Grace | Move 65% faster for 4.0 seconds. | Instant | 16.0s (off GCD) |
| Shift+1 | Guiding Star | Place a star on an ally or yourself for 30s. Maximum 3 total per Luminary; placing a fourth moves your oldest star. | Instant | 0.0s |
| Shift+2 | Pilgrim's Step | Consume your star on another ally to rush toward them. Stops at terrain. | Instant | 16.0s (off GCD) |
| Shift+3 | Last Light | For 4s, the first lethal hit leaves the ally at 1 HP and consumes this protection. Further damage can kill. | Instant | 45.0s (off GCD) |
| Shift+4 | Mend | Restore up to 28.0 of your own health. | 2.0s | 16.0s |
| Shift+5 | Starfall | Deal 16 damage and heal each of your starred allies for 8 per star within 28m and line of sight. | 1.5s | 12.0s |

## Fulcrum

| Key | Ability | Effect | Cast | Cooldown |
| --- | --- | --- | --- | --- |
| 1 | Graviton | Deal 14.0 damage to an enemy. | 1.3s | 0.0s |
| 2 | Inward | Pull an enemy up to 8m toward your anchor. Requires an active anchor within 28m and line of sight from it to the enemy. | Instant | 9.0s |
| 3 | Horizon | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | Instant | 12.0s (off GCD) |
| 4 | Anchor | Stun an enemy for up to 3.5 seconds, stopping movement and casting. | 0.6s | 16.0s |
| 5 | Umbra | Take 60% less damage for 5.0 seconds. | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 28.0 of your own health. | 2.0s | 16.0s |
| 7 | Tether | Drag your target up to 8.0 meters toward you. Works on an enemy or an ally. | Instant | 14.0s (off GCD) |
| Shift+1 | Gravity Anchor | Place a visible gravity anchor on the ground up to 10m ahead, stopping before walls. Lasts 20s. Replacing it ends its orbit. | 0.6s | 4.0s |
| Shift+2 | Outward | Push an enemy up to 8m away from your anchor. Requires an active anchor within 28m and line of sight from it to the enemy. | Instant | 9.0s |
| Shift+3 | Heavy Orbit | Your anchor creates a 6m slowing field for 6s. Enemies inside move 45% slower. | Instant | 16.0s |
| Shift+4 | Counterweight | Exchange positions with another ally. Both routes must be clear; cannot cross terrain. | Instant | 22.0s (off GCD) |
| Shift+5 | Collapse | After a 1.5s cast, consume your anchor to deal 22 damage and root enemies within 6m for up to 2s. Roots share diminishing returns. | 1.5s | 18.0s |

## Shared rules

Heat and Resolve cap at 100. Each Luminary owns at most three stars. Brands, stars, anchors, defensive states, roots and ground fields are authoritative and replicated. Class resources reset between rounds and at duel boundaries. Stars expire after 30 seconds; brands after 10.

Gravity Anchor is placed up to 10m in the direction faced, swept against terrain and projected onto the floor. It lasts 20s. Anchor abilities need the caster within 28m and line of sight; Inward and Outward also require anchor-to-target range and line of sight. Ground effects do not pass through cover. Counterweight exchanges immediately after validation; both swept routes must be clear.

Stuns, disorients, and roots share diminishing returns. Solar Flare breaks on damage. Rooted characters can cast but cannot jump or use movement abilities; Absolution clears roots and slows. Hold the Line prevents movement and displacement but allows turning; attacking ends it. Damage reductions use the strongest applicable reduction, not multiplication.

Last Light prevents one lethal hit by leaving 1 HP; it is not a resurrection. Intercede redirects at most 30 raw damage, requires ongoing range and line of sight, and cannot form recursive damage chains. Healing retains match dampening.

World bystanders cannot damage, control, or displace duelists, or heal/protect/exchange places with them. Self abilities remain available. Bot priorities exercise each identity; they are introductory sparring AI, not a competitive benchmark.

Anchor rings and timers, burning-field outlines, Supernova warnings, resource text, brand counts, star counts, and status icons expose combat state. Earthsplitter applies a brief stun with a small airborne launch. Exact character transformation animations, sound, and bespoke spell cinematics are not implemented by this class pass.
