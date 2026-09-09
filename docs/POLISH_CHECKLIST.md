# Starfall polish checklist

Priorities from the 2026-09-09 review. The owner authorized items 1, 3, and 5, then prioritized a reported RTX 5060 Ti performance problem ahead of them. Those three polish items and initial performance mitigations are implemented locally in 0.11.0. Audio belongs to the owner’s sound-engineer friend and is excluded from agent work. Other items remain proposals.

## Visual repass — 2026-09-09

Items 1/3/5 now also have a presentation pass: larger launch action cards and title hierarchy; consistent menu/status surfaces; settings actions below options; separate victory/defeat treatment with winning-team caption, duration and survivor cards; stronger rematch emphasis; inset ability-restriction borders/status strips and a distinct tooltip explanation. No audio or extra 3D effects. `menu_presentation.gd` handles presentation without changing round authority or ability validation. Verified 200 UI checks, 30 polish checks, online rematch/waiting, and 30 layout cases across three window sizes. Native captures are `artifacts/polish-{menu,settings,availability,results,defeat,pause}.png`.

## Review scope

Reviewed current source, design constraints, deployment workflow, and character-pipeline limitations. Ran a scripted local 3v3 scene and inspected fresh menu, settings, combat, and defeated-player captures. Forced death/results were presentation probes, not natural match outcomes. Rendering used Compatibility with software graphics in a virtual display; captures were 640×480. This does not establish Forward+ quality, normal-resolution readability, hardware performance, live-server reliability, or human combat feel. No gameplay code was changed.

Existing foundations: four authored champions, illustrated abilities, class resources/procs, cast bars, cooldown sweeps, auras/DR/CC readouts, target/focus frames, key rebinding, HUD editing, camera zoom persistence, local bots, queues/private lobbies, world chat/duels, movement prediction, and version/schema mismatch handling. These need selective refinement, not rebuilding.

## First: complete the basic player experience

- [x] **1. Clean up launch, pause, and results screens.** Fresh launch shows the match scoreboard, a disabled Resume button, and Return to menu while already in the menu. Champion selection remains in Settings. Give each state its own relevant controls, add Quit on desktop, and show the arena from a deliberate menu camera. **Done when:** launch/settings/pause/results each have a clear primary action and no irrelevant match controls. Evidence: `scripts/arena.gd`, `build_ui`, `refresh_menu`, `update_visuals`; fresh menu/settings captures.

- [ ] **2. Add combat and interface audio.** No audio assets or playback implementation were found. Prioritize casts, impacts, interrupts, low health, defeat, countdown, and UI confirmation; add footsteps/arena ambience and restrained music afterward. Give critical combat cues priority in the mix and add independent volume controls. **Done when:** players can recognize major combat events by sound, with visual equivalents and no overwhelming six-player mix.

- [x] **3. Make ability availability readable before pressing.** Cast rejection already explains range, facing, LOS, and target validity, but action-bar shading primarily reflects cooldowns, CC, procs, and death. Add distinct range/resource/target feedback using the same rules as validation; keep final combat decisions authoritative. **Done when:** players can tell why a ready-looking ability cannot fire, and feedback changes promptly as positioning or resources change. Evidence: `validate_spell`, `update_visuals`, `ClassMechanics.validate`.

- [x] **4. Give eliminated players something useful to do.** The defeated-player probe left the normal HUD and camera view with greyed abilities. Add a clear eliminated state, surviving teammate count, cycle-teammate spectator camera, and a short explanation of the killing damage/control sequence. **Done when:** a dead 3v3 player understands what happened and can follow surviving teammates until the round ends. Preserve the existing no-respawn-during-round rule. Implemented: eliminated card, living-team count, previous/next teammate buttons and existing target-cycle bindings, automatic survivor fallback, cached recent incoming-event recap, personal HUD suppression and results/rematch cleanup. Recap uses reliable existing events (attacker, damage/control labels); exact damaging spell names are not available in that event payload. Validated 22 spectator checks, 200 UI checks, 30 polish checks and native staged screenshots.

- [x] **5. Finish the end-of-round loop.** Results currently reuse the central menu with a victory/defeat line. Offline text says to choose Local sparring, but that row is hidden in results; dedicated matches auto-rematch while results messaging refers to the host. Add one-click offline rematch, accurate online countdown/waiting status, clear leave/requeue choices, and a compact round summary. **Done when:** every mode communicates what happens next and offers the correct next action. Evidence: `finish_round`, `_dedicated_rematch`, `refresh_menu`.

- [ ] **6. Ship a player-ready download/update path.** Server Docker build/deploy automation exists; this checkout has no client export presets, client-release job, or launcher. Package supported desktop builds, expose client version, and make mismatch messages lead to a usable update/download route. An automated updater can follow a reliable manual download. **Done when:** a friend on a clean machine can download, launch, join, and recover from an outdated build without installing Godot. Live deployment status was not checked.

## Next: make combat easy to read and satisfying

- [ ] **7. Turn champion selection into a useful introduction.** Replace or supplement the role dropdown with the existing character model/portrait, role, resource explanation, signature abilities, and a short playstyle summary. Add an optional practice/help entry for Tab targeting, mouse steering, ally selection, interrupts, and LOS. **Done when:** a new player can choose a class and complete a simple practice fight without external docs. Tutorial text was deliberately removed from the HUD; keep help opt-in and outside normal combat.

- [ ] **8. Give major abilities distinct visual impact.** Authored models and some class-specific effects already exist, but many events still share beams, flashes, and floating text. Prioritize recognizable cast anticipation, release, impact, defensive activation, interrupts, and ground-effect boundaries for signature abilities. **Done when:** players can identify the important enemy action and its affected area at the normal camera distance during 3v3. Evidence: `show_event`, `beam`, `class_mechanics.gd`, `vanguard_strike.gd`.

- [ ] **9. Improve HUD hierarchy and team information.** Resource values currently appear as text; party/enemy rows lack the richer aura strips of unit frames. Add readable resource meters and threshold markers, prioritize dispellable/important CC and casts on team frames, and consider target-of-target. Reduce overlapping overhead text and optional combat-text noise. **Done when:** target, threatened ally, important cast, and personal resource state remain easy to find in a busy match. Validate default layouts at 1280×720, 1080p, ultrawide, and high DPI before declaring them polished.

- [ ] **10. Add comfort and accessibility settings.** Keybinds, window modes, resolution, slot sizing, HUD placement, and zoom persistence already work. Add mouse sensitivity/invert options, broader UI/text scaling, color-independent team/status cues, and reduced flash/effect options. **Done when:** settings persist and players can retain essential information with larger text, alternate colors, and reduced effects. Mouse rotation currently uses a fixed multiplier in `_input`.

- [ ] **11. Validate consistent performance and offer quality presets.** Recent optimization results are promising, but the context still records a pending retest on the owner's hardware. Provide in-game quality options for expensive effects/shadows, an FPS limit, and an optional performance readout. Profile full six-character combat, first-use abilities, and repeated rounds on the actual target machines before deciding whether LODs or further optimization are needed. **Done when:** agreed target machines sustain the chosen frame-time budget in representative sessions; this review's software renderer provides no performance verdict.

- [ ] **12. Refine animation where players notice it most.** Preserve the approved character designs and forge workflow. Inspect strafing/backpedaling foot sliding, ramp contact, weapon-hand alignment, cast-to-movement transitions, attacks, and death poses at gameplay camera distance. These are partly documented limitations, not all newly reproduced defects. **Done when:** recorded movement/combat sequences have no distracting sliding, clipping, or abrupt pose changes. Evidence: `docs/CHARACTER_PIPELINE.md` and current class presentation modules.

## Then: make repeated sessions dependable

- [ ] **13. Improve joining friends and recovering from trouble.** Queue population, private codes, readable connection failure, version rejection, and bot takeover already exist. Add copy-code, clearer player identity/team roster, connection progress with cancel/retry, and a deliberate reconnect/rejoin policy. **Done when:** test players can form the intended teams and recover from disconnects, full lobbies, and mismatches without ambiguity. Verify against a real server; do not infer production failures from source review.

- [ ] **14. Run structured human balance/feel sessions.** Test each class in duels and mixed 3v3: burst survival, healing pressure, CC/DR chains, Fulcrum displacement, Vanguard protection, Luminary saves, and latency feel. Record round duration, notable deaths, and player feedback before tuning. **Done when:** multiple sessions produce documented issues and repeat tests show improvement. Automated correctness tests do not establish enjoyable balance.

- [ ] **15. Make offline practice adjustable.** Existing bots navigate, kite, heal, interrupt, and use class mechanics; opponent choice already exists. Add a passive target/practice mode, reset health/cooldowns, and adjustable bot pressure, then improve target coordination and healer positioning based on observed play. **Done when:** players can learn a mechanic deliberately and then practice it against increasing pressure.

## Suggested first batch

Items 1, 3, and 5 are implemented and checked. Performance controls now offer a 60 FPS match default, 30 FPS menus/results, 15 FPS unfocused, Balanced/High/Performance presets, optional 3D resolution scaling, and an FPS readout. The reported RTX 5060 Ti lag still needs a player retest; GPU utilization alone did not establish its cause. No uncontended hardware benchmark was available. Audio is assigned to the owner’s friend; do not begin audio work. Follow with death/spectating and champion introduction. Client packaging is a prerequisite for wider friend testing; pursue it before expanding the test audience.

Keep additional champions, new maps, ranked systems, and progression outside this polish batch. The current roster and arena provide enough scope to make one complete experience feel finished.

## Documentation follow-up

The existing roadmap contains stale statements about missing movement prediction, primitive models, absent resource systems, and server deployment automation. Its launcher/client-distribution gap remains relevant. Reconcile those entries with current code when accepting this proposed backlog; do not mistake old roadmap prose for current missing features.
