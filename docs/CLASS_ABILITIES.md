# Class abilities

Current implementation, September 15, 2026. Fulcrum harnesses gravity and dark energy through Compression, Expansion, Ruin and Divide. Six explicitly labeled anchor range variants use 3m / 8m / 15m. Graviton and Fulcrum's Starfall are retired. Trinket remains Ctrl+1; Gravity Flow is Ctrl+2. Existing saved bindings are preserved and missing abilities enter free slots.

Range is the actual maximum distance to the selected target. Self-targeted abilities show their stored 0m range; their effect radii, anchor limits, or movement distances are listed separately. Cast times below are the ordinary values; the effect descriptions explain temporary instant-cast buffs. Outlaw's provisional cooldowns and unspecified tuning are documented in OUTLAW_CLASS.md.

## Ember

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Kindle | Deal 160 damage. Gain 20 Heat and add a brand (up to 3) for 10s. | 18.0 m | 1.5s | 0.0s |
| 2 | Flashpoint | Consume your brands: 120 + 60 damage per brand. Three brands also deal 100 splash damage within 5m. Gain 10 Heat. | 16.5 m | Instant | 7.0s |
| 3 | Disrupt | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | 16.5 m | Instant | 12.0s (off GCD) |
| 4 | Stasis | Stun an enemy for up to 4.0 seconds, stopping movement and casting. | 15.0 m | 0.8s | 16.0s |
| 5 | Fire Barrier | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 336 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 30.0s |
| 7 | Blink | Blink up to 8.0m in your movement-input direction, including diagonals. With no movement input, blink forward along your camera's heading. Two charges; restores one charge every 14.0s. Stops at solid terrain. Off the global cooldown; usable while casting without interrupting the cast. | Self (0.0 m) | Instant | 14.0s (off GCD) |
| Shift+1 | Supernova | Requires 40 Heat. Consume all Heat: 180 + 4 damage per Heat to enemies within 5m of the target. | 18.0 m | 2.2s | 20.0s |
| Shift+2 | Solar Flare | Aim a 4m, 108-degree cone in front of you. No selected target is needed. Incapacitate enemies you hit for up to 3s. Terrain blocks the effect. Any damage breaks it; uses incapacitate diminishing returns. | 4 m cone | Instant | 18.0s |
| Shift+3 | Cinderstep | Requires and spends 20 Heat. Skate for 3s with +80% movement speed; steer normally. Leave a 3m-wide flame trail: each segment lasts 5s, deals 40 damage/sec and slows by 45%. | Self (0.0 m) | Instant | 18.0s (off GCD) |
| Shift+4 | Stoke | Generate 30 Heat. Maximum 100 Heat. | Self (0.0 m) | 1.5s | 12.0s |
| Shift+5 | Burning Wake | Create a burning ring for 5s: 5m outer radius, safe center inside 3m. The ring slows enemies by 45% and deals 60 damage/sec (+50%). | Self (0.0 m) | Instant | 18.0s |
| Shift+6 | Ash | Become an invulnerable spirit for up to 6s, invisible to enemies, with +50% movement speed. Press again to recall early. Freeze for 0.65s as ash follows your route and rebuilds you; invulnerability ends with spirit form. Cannot cast other abilities during either phase. | Self (0.0 m) | Instant | 90.0s (off GCD, provisional) |
| Ctrl+1 | Trinket | Remove all crowd control, roots, slows and interrupt lockouts instantly. Usable while controlled; 2-minute cooldown. Ground hazards may reapply their effects. | Self (0.0 m) | Instant | 120.0s (off GCD) |

## Vanguard

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Sundering Blow | Deal 130 damage and gain 20 Resolve (maximum 100). Expose this enemy to your next Oathbreaker for 6s. | 2.5 m | Instant | 0.0s |
| 2 | Oathbreaker | Spend all Resolve: deal 150 + 3 damage per Resolve, plus 80 against your exposed target. | 2.5 m | 0.8s | 7.0s |
| 3 | Pummel | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | 3.0 m | Instant | 12.0s (off GCD) |
| 4 | Bash | Stun an enemy for up to 3.0 seconds, stopping movement and casting. | 2.5 m | Instant | 16.0s |
| 5 | Iron Skin | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 336 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 30.0s |
| 7 | Charge | Immediately root an enemy for up to 1.5s, then rush along a safe route at 32m/s and deal 60 damage on arrival. Line of sight is required only when casting. Uses root diminishing returns. | 16.5 m | Instant | 12.0s (off GCD) |
| Shift+1 | Intercede | Rush to another ally. For 5s redirect 30% of their damage to yourself, up to 300 damage total, while within 18m and line of sight. Redirected damage grants Resolve. | 16.5 m | Instant | 18.0s (off GCD) |
| Shift+2 | Hold the Line | For 4s, stand still and take 70% less frontal damage; resist displacement. Turning is allowed. Attacking ends this stance. Does not stack with stronger reduction. | Self (0.0 m) | Instant | 20.0s (off GCD) |
| Shift+3 | Challenge | For 6s, this enemy attacking your allies grants you 15 Resolve per hit, at most once per second. | 16.5 m | Instant | 16.0s |
| Shift+4 | Earthsplitter | Deal 120 damage and stun enemies in a narrow 8m forward line for up to 1s. Shares stun diminishing returns. | 6.0 m | 0.7s | 18.0s |
| Shift+5 | Unbroken | Spend 40 Resolve to gain 4s of 60% damage reduction. | Self (0.0 m) | Instant | 20.0s (off GCD) |
| Shift+6 | Crippling Verdict | Slow an enemy within 3.5m by 60% for 6s. Instant, 15s cooldown, normal global cooldown. No damage. | 3.5 m | Instant | 15.0s |
| Ctrl+1 | Trinket | Remove all crowd control, roots, slows and interrupt lockouts instantly. Usable while controlled; 2-minute cooldown. Ground hazards may reapply their effects. | Self (0.0 m) | Instant | 120.0s (off GCD) |

## Luminary

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Smite | Deal 100 damage to an enemy. | 18.0 m | 1.5s | 0.0s |
| 2 | Falling Star | Heal 270. Consume one of your stars on the target to heal 240 more. | 18.0 m | Instant | 7.0s |
| 3 | Absolution | Remove stun, root and slow. Consume one of your stars to grant 3s immunity to roots and slows. | 18.0 m | Instant | 10.0s (off GCD) |
| 4 | Rebuke | Stun an enemy for up to 3.0 seconds, stopping movement and casting. | 15.0 m | 1.0s | 18.0s |
| 5 | Sanctuary | An ally or you takes 60% less damage for 5.0 seconds. | 18.0 m | Instant | 22.0s (off GCD) |
| 6 | Stitchlight | Heal 405. A starred target echoes 135 healing to one other starred ally within 18m and line of sight. | 18.0 m | 1.8s | 0.0s |
| 7 | Grace | Move 65% faster for 4.0 seconds. | Self (0.0 m) | Instant | 16.0s (off GCD) |
| Shift+1 | Guiding Star | Place a star on an ally or yourself for 30s. Maximum 3 total per Luminary; placing a fourth moves your oldest star. | 18.0 m | Instant | 0.0s |
| Shift+2 | Pilgrim's Step | Consume your star on another ally to rush toward them. Stops at terrain. | 16.5 m | Instant | 16.0s (off GCD) |
| Shift+3 | Last Light | For 4s, the first lethal hit leaves the ally at 1 HP and consumes this protection. Further damage can kill. | 18.0 m | Instant | 45.0s (off GCD) |
| Shift+4 | Mend | Restore up to 336 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 30.0s |
| Shift+5 | Starfall | Deal 160 damage and heal each of your starred allies for 120 per star within 18m and line of sight. | 18.0 m | 1.5s | 12.0s |
| Ctrl+1 | Trinket | Remove all crowd control, roots, slows and interrupt lockouts instantly. Usable while controlled; 2-minute cooldown. Ground hazards may reapply their effects. | Self (0.0 m) | Instant | 120.0s (off GCD) |

## Fulcrum

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Ruin | Command a smoking dark-matter greatsword at your selected enemy for 108 damage. Spend 33 Meditation. Press again within 6s with more than 66 Meditation remaining to spend another 33 and slash left. Right then left unlocks Divide for 6s. After the left slash, Ruin locks out for 8s — only two slashes per combo. Casting Divide copies whatever is left of that 8s onto Divide's own cooldown, so the two then tick down together. Terrain blocks Ruin. | 10.0 m | Instant | 0.0s |
| 2 | Compression · Close | Place an anchor 3.0m ahead (stops at terrain). Pull visible enemies within 6m into a black hole, impale them for 132 damage and stun for 1.2s. Generate 20 Meditation when an enemy is caught. The anchor remains for 3s: use Anchor Exchange or Dark Growth. Range variants share a 12s cooldown per polarity. | Self (3.0 m) | Instant | 12.0s |
| 3 | Compression · Mid | Place an anchor 8.0m ahead (stops at terrain). Pull visible enemies within 6m into a black hole, impale them for 132 damage and stun for 1.2s. Generate 20 Meditation when an enemy is caught. The anchor remains for 3s: use Anchor Exchange or Dark Growth. Range variants share a 12s cooldown per polarity. | Self (8.0 m) | Instant | 12.0s |
| 4 | Compression · Long | Place an anchor 15.0m ahead (stops at terrain). Pull visible enemies within 6m into a black hole, impale them for 132 damage and stun for 1.2s. Generate 20 Meditation when an enemy is caught. The anchor remains for 3s: use Anchor Exchange or Dark Growth. Range variants share a 12s cooldown per polarity. | Self (15.0 m) | Instant | 12.0s |
| 5 | Umbra | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 336 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 30.0s |
| 7 | Tether | Drag your target up to 8.0 meters toward you. Works on an enemy or an ally. | 16.5 m | Instant | 14.0s (off GCD) |
| Shift+1 | Expansion · Close | Place an anchor 3.0m ahead (stops at terrain). A purple spherical blast deals 100 damage and launches visible enemies within 3.6m away with momentum. The anchor remains for 3s: use Anchor Exchange or Dark Growth. Range variants share a 12s cooldown per polarity. | Self (3.0 m) | Instant | 12.0s |
| Shift+2 | Expansion · Mid | Place an anchor 8.0m ahead (stops at terrain). A purple spherical blast deals 100 damage and launches visible enemies within 3.6m away with momentum. The anchor remains for 3s: use Anchor Exchange or Dark Growth. Range variants share a 12s cooldown per polarity. | Self (8.0 m) | Instant | 12.0s |
| Shift+3 | Expansion · Long | Place an anchor 15.0m ahead (stops at terrain). A purple spherical blast deals 100 damage and launches visible enemies within 3.6m away with momentum. The anchor remains for 3s: use Anchor Exchange or Dark Growth. Range variants share a 12s cooldown per polarity. | Self (15.0 m) | Instant | 12.0s |
| Shift+4 | Anchor Exchange | Within 3s of placing either anchor, exchange positions with it and consume the follow-up. Requires a clear travel path; cannot be used while rooted. Off the global cooldown. | Self (0.0 m) | Instant | 0.0s (off GCD) |
| Shift+5 | Dark Growth | Within 3s of placing either anchor, consume it to grow black grass outward over 1s, reaching a 6m radius. Lasts 6s and slows enemies by 45%. Off the global cooldown. | Self (0.0 m) | Instant | 0.0s (off GCD) |
| Shift+6 | Divide | Requires Ruin right then left. Command a 15m vertical sword slash toward your selected enemy after a 0.3s charge. No manual aim. Deals 162 damage in a 3m-wide line. Its 0.65s lingering hitbox hits each enemy once. Penetrates corners and up to 3m of cover; full pillars block it. Leaves a 6s rift that slows by 50%. No additional resource cost. Casting Divide inherits whatever remains of Ruin's 8s lockout. Gravity Flow removes the charge and detonates each enemy it hits for extra damage to nearby foes. | 15.0 m | 0.3s | 0.0s |
| Shift+7 | Entropy | Apply a 15s DoT: 20 damage and 10 Meditation each second. Instant only when none of your Entropy effects are active; otherwise casts in 0.8s, including refreshes. No per-caster stacking or delayed ticks. Cleansing triggers a 3s silence on the cleanser. Meditation caps at 100. | 18.0 m | 0.8s | 0.0s |
| Ctrl+1 | Trinket | Remove all crowd control, roots, slows and interrupt lockouts instantly. Usable while controlled; 2-minute cooldown. Ground hazards may reapply their effects. | Self (0.0 m) | Instant | 120.0s (off GCD) |
| Ctrl+2 | Gravity Flow | For 8s, Ruin and Divide bypass the global cooldown. Divide charges instantly and each enemy it hits also detonates for damage to nearby foes. Resource and combo requirements still apply. 60s cooldown. | Self (0.0 m) | Instant | 60.0s (off GCD) |

## Outlaw

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Starshot | Fire for 80 damage. Unkickable; cast while moving 30% slower. | 18.0 m | 0.7s | 0.0s |
| 2 | Severe | Slash for 20% current health. Bleed for 20 damage each second for 5s and slow by 60% for 6s. Unkickable; cast while moving. Instant for 1.5s after Roll. | 3.3 m | 0.6s | 4.0s |
| 3 | Trickshot | Deal 180 damage during airborne Backflip or a flying Coin Toss. Coin shots ricochet around cover through clear paths. One use per combo; a hit grants 1 Defense Detonation stack (max 3). | 18.0 m | Instant | 0.0s (off GCD) |
| 4 | Backflip | Leap backward; usable while jumping. While airborne: 50% less damage, CC immunity, and one Trickshot opportunity. Ends on landing. | Self (0.0 m) | Instant | 12.0s (off GCD) |
| 5 | Ward | Take 60% less damage for 5.0 seconds. | Self (0.0 m) | Instant | 22.0s (off GCD) |
| 6 | Mend | Restore up to 336 of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you. | Self (0.0 m) | 2.0s | 30.0s |
| 7 | Roll | Roll 7.8m in your movement direction; camera-forward if stationary. Gain 25% move speed for 5s and one instant Severe for 1.5s on completion, even against a wall. | Self (0.0 m) | Instant | 10.0s (off GCD) |
| Shift+1 | Coin Toss | Throw a coin for up to 1.8s, carrying your momentum. Trickshot can ricochet from it around cover. Terrain or a successful shot ends the combo. | Self (0.0 m) | Instant | 14.0s |
| Shift+2 | Defense Detonation | Aim over your shoulder. Left-click charges for 0.6s, then spends all stacks (1–3), firing every 0.13s for 100 base damage per hit. Misses spend stacks. Firing uses GCD; last shot exits aim. Press again to cancel. | Self (0.0 m) | Instant | 0.0s (off GCD) |
| Shift+3 | Deadeye | Mark all enemies. During the unkickable 3s cast, detect and target stealthed Null with his normal detection warning. Walk while casting; hit enemies within 18m and clear sight at completion for 40% maximum health. Cannot jump. Interrupted casts refund cooldown. | 18 m sight at completion | 3.0s | 90.0s |
| Shift+5 | Lasso | Unkickable moving cast: lasso into a dropkick, stun during travel, then knock back and knock down for 2.5s. Rebound; gain 1 Defense Detonation stack. Usable during Backflip with slowed drift and CC immunity; landing cancels the cast. | 18.0 m | 0.7s | 20.0s |
| Shift+6 | Boot Kick | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | 3.0 m | Instant | 12.0s (off GCD) |
| Ctrl+1 | Trinket | Remove all crowd control, roots, slows and interrupt lockouts instantly. Usable while controlled; 2-minute cooldown. Ground hazards may reapply their effects. | Self (0.0 m) | Instant | 120.0s (off GCD) |

## Null

| Key | Ability | Effect | Range | Cast | Cooldown |
| --- | --- | --- | --- | --- | --- |
| 1 | Temporal Strike | Strike your enemy for 120 damage. | 3.0 m | Instant | 0.0s |
| 2 | Backstab | Deal 388 damage from behind your target. 30s cooldown. | 3.0 m | Instant | 30.0s |
| 3 | Kick | Interrupt an enemy's cast and lock out their spells for 4.0 seconds. | 3.0 m | Instant | 12.0s (off GCD) |
| 4 | Nerve Lock | Stun an enemy within 3.5m for 4s. Uses stun diminishing returns. | 2.5 m | Instant | 20.0s |
| 5 | Stealth | Requires 8s out of direct combat; no cooldown. Chronoshift can re-stealth in combat for 100 Essence, once per 120s. Press again to end Stealth. You appear at 50% opacity. Enemies must remain within 3.5m for 0.7s to detect and target you; no nameplate. Attacking, aimed abilities or incoming damage break Stealth. Damage-over-time ticks do not extend combat. | Self (0.0 m) | Instant | 0.0s (off GCD) |
| 6 | Haste | Move 50% faster for 6s. 25s cooldown. | Self (0.0 m) | Instant | 25.0s (off GCD) |
| 7 | Blindside | After an unkickable 0.28s wind-up, teleport behind your target without breaking Stealth. Usable while moving or jumping. Off the global cooldown; requires a safe landing. | 18.0 m | 0.28s | 15.0s (off GCD) |
| Shift+1 | Vantage Point | Usable while jumping. Rise for 0.5s, then ease into an accelerating dive. Longer dives travel faster. Contact deals 77 damage and knocks down with a 4s stun. No rebound. | 18.0 m | Instant | 25.0s |
| Shift+2 | Regen Pot | Remove attached damage-over-time effects, then regenerate 268.8 health over 6 seconds. | Self (0.0 m) | Instant | 40.0s (off GCD) |
| Shift+3 | Chronoshift | Choose an ability by pressing its normal keybind to refresh and immediately cast it. Costs 100 Essence. Reset lock: twice that ability's cooldown. Stealth can be used in combat, with a 120s reset lock. Cannot reset Kick. Normal cast requirements still apply. | Self (0.0 m) | Instant | 0.0s (off GCD) |
| Shift+4 | Smoke Bomb | Drop a 3m-radius smoke cloud for 6s. Only enemies of the smoke's owner are blocked from casting across its inside/outside boundary. Your team can attack and heal through your smoke. Both outside can interact through the cloud. Existing damage-over-time effects continue. | Self (0.0 m) | Instant | 30.0s (off GCD) |
| Ctrl+1 | Trinket | Remove all crowd control, roots, slows and interrupt lockouts instantly. Usable while controlled; 2-minute cooldown. Ground hazards may reapply their effects. | Self (0.0 m) | Instant | 120.0s (off GCD) |

## Shared rules

Base positive cast ranges are reduced by 25%, rounded to the nearest 0.5m, and capped at 18m. Severe then receives its explicit 10% increase from 3m to 3.3m, without another rounding pass. Opposing arena spawn lines are 20m apart, so direct targeted spells cannot reach the opposing spawn at the start. This does not prevent self abilities or change separately specified effect radii and displacement distances. Luminary healing links and Intercede's ongoing protection require allies within 18m and line of sight.

Heat, Resolve and Meditation cap at 100. Entropy deals 20 damage and generates 10 Meditation per second for 15 seconds. It is instant only with no active Entropy from that caster; spreading or refreshing uses a 0.8s cast. Cleansing it inflicts a three-second silence on the cleanser. Natural expiration, death and duel cleanup do not trigger backlash. Other damage defenses and silence diminishing returns remain applicable.

Ruin costs 33 Meditation per slash, dealing 108 damage to your selected enemy. Right starts the combo; left requires strictly more than 66 remaining and must follow within six seconds. Left unlocks Divide for six seconds and locks Ruin itself out for eight seconds — only two slashes per combo. Divide requires no further resource, uses the selected enemy with no manual aiming, charges 0.3s, then deals 162 damage in a 15m by 3m line. Casting Divide copies whatever remains of Ruin's eight-second lockout onto its own cooldown, so the two then tick down together. The 0.65s lingering area hits each enemy once. It can pass through up to 3m total solid cover around corners; a full pillar blocks it. The six-second ground rift slows by 50%. Gravity Flow lasts eight seconds on a 60-second cooldown: slashes bypass GCD, Divide has no charge, and each enemy a flow-charged Divide hits also detonates for damage to enemies within 5m.

Vanguard's Charge immediately applies a three-second root on a successful cast, subject to root immunity and diminishing returns. It then moves continuously at 32m/s along a collision-checked route and deals its existing 6 damage on arrival at melee range. Range, facing and LOS are checked initially; losing LOS afterwards does not cancel the rush. Detours use ramp entrances and avoid pillars, walls and terrace ledges. A target with no safe route is rejected before spending the cast. Target death or loss of duel permission cancels remaining travel/damage. The individual 12-second cooldown and off-GCD behavior are unchanged.

Each Luminary owns at most three stars. Brands, stars, anchors, defensive states, roots and ground fields are authoritative and replicated. Class resources reset between rounds and at duel boundaries. Stars expire after 30 seconds; brands after 10.

Compression and Expansion place anchors 3m / 8m / 15m ahead, swept against collision and projected onto safe ground. Each polarity shares a twelve-second cooldown across its range variants. Compression pulls visible enemies in a 6m radius, deals 132 damage and stuns for 1.2s, subject to normal control rules. It grants 20 Meditation when at least one valid enemy is caught. Expansion's 3.6m purple sphere deals 100 damage and launches enemies with momentum. Sight is judged from the caster, not the anchor: an enemy the anchor could see but you cannot is not affected. Each anchor stays for three seconds: exchange positions with it along a clear path, or consume it to grow a six-second black-grass field to a 6m radius over one second, slowing by 45%. These follow-ups are off GCD and mutually exclusive for that anchor.

Solar Flare is an untargeted 4m cone with a 108-degree total angle, aimed using Ember's character heading. Its white flame burst and local ground outline appear briefly after a successful cast, including a cast that hits no enemies. Enemies inside the cone must also pass terrain line-of-sight and duel-permission checks. It retains its 18s cooldown, ordinary global cooldown and up-to-3s incapacitate, which breaks on damage.

Blink has two stored casts, restoring one charge at a time every 14s. Spending the second charge does not restart the first recharge. It moves up to 8m along the movement input sampled when casting, including diagonals; with no movement input it uses camera heading, even during free look or airborne momentum. It is off the global cooldown and stops at solid terrain. The hotbar shows remaining charges and a recharge countdown; one available charge stays usable while the other recharges.

Control categories have independent diminishing returns. Rooted characters can cast but cannot jump or start movement abilities; Absolution clears roots and slows. An already accepted Charge completes its committed travel. Hold the Line prevents movement and displacement but allows turning; attacking ends it. Damage reductions use the strongest applicable reduction, not multiplication.

Last Light prevents one lethal hit by leaving 1 HP; it is not a resurrection. Intercede redirects at most 30 raw damage, requires ongoing range and line of sight, and cannot form recursive damage chains. Mend always heals up to 28, without dampening. Other healing retains match dampening in arena matches only; world healing is never dampened.

World bystanders cannot damage, control, or displace duelists, or heal/protect/exchange places with them. Self abilities remain available. Bot priorities exercise each identity; they are introductory sparring AI, not a competitive benchmark.

Anchor effects, burning-field outlines, Supernova warnings, resource text, brand counts, star counts, and status icons expose combat state. Ruin continuation and Divide readiness highlight their hotbar icons. Earthsplitter applies a brief stun with a small airborne launch.
