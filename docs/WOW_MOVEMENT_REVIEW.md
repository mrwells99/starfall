**Starfall movement controls: a WoW Classic comparison**

Starfall already has the foundation for responsive arena movement. The highest-value next pass is to make mouse gestures, facing, spell input, and jumping behave consistently at their boundaries. Changing the run speed or adding acceleration first would leave several concrete input problems unresolved.

The reference is Classic-style ground combat with keyboard and mouse. Blizzard's original manual establishes keyboard turning, strafing, autorun, jumping, free camera orbit, and wheel zoom. Its later beginner guide also documents right-button steering, two-button forward movement, and clicking characters to target them. These sources establish the control vocabulary; they do not establish exact current Classic physics or every mouse-button transition. [Blizzard manual, printed pp. 16 and 20](https://bnetcmsus-a.akamaihd.net/cms/template_resource/LO0VQ46XB1281555957773363.pdf), [Blizzard movement guide](https://worldofwarcraft.blizzard.com/en-us/news/20151231).

The code baseline is commit `9370dad`, inspected September 9, 2026, using Godot 4.5.1. The findings below record the original audit. The subsequent implementation is described in the movement-controls section of [GAME_DESIGN.md](/home/plato/codex/docs/GAME_DESIGN.md:123) and the input section of [TECHNICAL_ARCHITECTURE.md](/home/plato/codex/docs/TECHNICAL_ARCHITECTURE.md:223). Movement animation and audio are separate workstreams. Spell definitions, movement ability ranges, CC rules, and combat balance are outside this proposed controls pass.

**Existing behavior worth preserving.** Ground movement starts, stops, and reverses without an acceleration ramp. Diagonal input is normalized. Strafing preserves facing. Left-button drag changes the camera; right-button motion also changes intended character facing; both buttons request forward movement. Turn bindings become strafe bindings while right mouse is held. These are useful building blocks already present in [arena.gd](/home/plato/codex/scripts/arena.gd:2198).

Jumping retains world-space horizontal takeoff velocity while airborne. Turning or releasing a movement key does not redirect that velocity; collisions and immobilizing effects can still stop it. Movement is predicted locally, so a client does not wait for the server before moving. Camera position follows the interpolated actor position, while mouse look updates directly from input events. Replacing these systems wholesale is unnecessary.

| Area | Current Starfall behavior | Recommended treatment |
|---|---|---|
| Start, stop, reverse | Immediate grounded velocity change | Preserve and regression-test |
| Forward and strafe | 6.5 world units/second before modifiers | Measure against a reference before tuning |
| Backward movement | 3.8 units/second, including backward diagonals | Preserve initially; measure the diagonal rule separately |
| Keyboard turning | 2.5 radians/second, about 143°/second | Make separately adjustable if needed |
| Default keys | A/D strafe, Q/E turn | Keep existing bindings; offer an optional Classic preset |
| Mouse sensitivity | Uses scaled mouse displacement | Correct to unscaled displacement |
| Mouse gesture ownership | Reads held buttons even when UI owns the click | Fix first |
| Facing and ability input | Facing updates during movement sampling; actions can run earlier | Fix ordering |
| Jump transport | One command carries the jump boolean | Add loss-resistant, deduplicated delivery |
| Camera settings | Sensitivity, invert Y, wheel distance | Add deliberate follow/recenter options after input fixes |
| Autorun and walk | No corresponding bindable actions | Autorun next; walk lower priority |

These numerical values describe Starfall's source, not verified WoW values. A Starfall world unit has not been calibrated to a WoW yard.

**Mouse input has a reproducible UI conflict.** Camera motion is processed in `_input()` using global button state, whereas mouse capture begins later in `_unhandled_input()`. A click can belong to a health frame or another control and still influence camera rotation. The movement sampler independently treats both held buttons as a forward command.

A temporary runtime probe placed a mouse-blocking Control over the game. A drag changed camera yaw while the pointer was not captured. Holding both buttons produced a movement vector of `(0, -1)` despite the blocking UI. This is more than a theoretical concern about input routing. Godot documents that `_input()` runs before GUI handling and `_unhandled_input()` afterward, which explains why merely accepting a UI event does not undo the earlier camera update. [Godot 4.5 Viewport input propagation](https://docs.godotengine.org/en/4.5/classes/class_viewport.html#class-viewport-method-push-input).

The fix should track where each gesture began. A world-origin drag owns camera control until release; a UI-origin drag remains a UI interaction even if the cursor leaves the frame. Only a valid world gesture should enable two-button movement. The second button must join an existing world gesture without activating UI behind the captured cursor. Releasing one button must transition cleanly into the behavior of the other.

This requires more than checking whether the cursor currently overlaps UI: a player turning the camera can pass over HUD elements, and that should not interrupt steering. Focus loss, menus, edit mode, death, and disconnect should explicitly terminate active gestures and clear temporary movement requests. Returning to the game should require a fresh gesture.

**Sensitivity currently depends on display scaling.** Camera rotation reads `InputEventMouseMotion.relative`. The UI scale option changes the window's content scale factor. Godot explicitly warns that `relative` is scaled with content and can make captured mouse sensitivity resolution-dependent; it recommends `screen_relative` instead. A runtime event transformation confirmed that a 50-unit relative displacement became 25 under a half-scale transform while `screen_relative` remained 50. [Godot 4.5 mouse-motion reference](https://docs.godotengine.org/en/4.5/classes/class_inputeventmousemotion.html).

Use unscaled displacement for world-camera rotation, retain the sensitivity slider and invert-Y setting, and avoid adding mouse acceleration or smoothing by default. Mouse displacement should not be multiplied by frame delta. Preserve immediate event handling, which is already enabled with `Input.use_accumulated_input = false`.

The practical acceptance criterion is consistent degrees of rotation for the same reported unscaled displacement at every supported UI scale and resolution. A physical mouse comparison still needs matching DPI and native Windows/Linux testing; this change alone cannot guarantee identical OS or device behavior. Existing saved sensitivity may feel different after removing its accidental scaling, so provide a clear way to recalibrate without resetting other settings.

**Camera direction and character facing need an explicit handoff.** Right-button mouse motion copies camera yaw into `local_yaw`, but right-button press itself does not. After looking sideways with left drag, entering right-button steering without moving the mouse leaves character facing on the old heading. The source path and a headless state probe both retained actor yaw 0 with camera yaw at approximately 1.571 radians.

Recommended behavior: entering a valid world steering gesture should align intended facing with camera yaw when the character is allowed to turn. Two-button forward movement should then follow that heading immediately. Left-only orbit should preserve independent facing. During a stun, the camera may remain inspectable while actor turning follows existing CC restrictions; restoration of control needs a defined transition rather than an accidental snap.

This alignment-on-entry rule is a proposed consistency improvement. The cited Blizzard material does not specify every transition precisely. Native testing must cover left-to-right handoff, right-to-left handoff, simultaneous presses, and both release orders. The headless probe does not validate OS pointer capture or cursor restoration.

**Fast turning and casting can use stale movement state.** This deserves the same priority as mouse ownership because it affects the feel of PvP inputs. Mouse motion updates `local_yaw`, but actor yaw is normally applied in the next movement sample. `send_action()` can validate an ability before that sample. Online, the action message contains a spell slot and target, but no movement sequence or facing sample tying the action to the player's input at that moment. See [action handling](/home/plato/codex/scripts/arena.gd:2420) and [movement sampling](/home/plato/codex/scripts/arena.gd:2198).

A targeted validation probe placed an enemy behind the actor, set intended facing toward it, and checked the existing spell rules. Validation returned `Face your target` before intended facing was applied and an empty error afterward. This reproduces the stale-state condition; it is not a measurement of its frequency in live matches. Releasing movement immediately before a cast warrants an equivalent test because casting also examines movement intent.

Recommended design: sample the relevant movement/facing intent in a defined order before submitting an action. Associate online actions with that input state using sequence information or a bounded action-time input sample. The server must still enforce ownership, finite values, CC, speed, position, range, line of sight, resources, and cooldowns. An action must not gain authority to teleport the actor or bypass a stun. Older movement packets must not restore a heading that an accepted newer action sample superseded.

A naive extra movement send before the action is insufficient if that movement packet can be lost. Equally, making all movement reliable would not solve the local ordering problem. This work changes input handling around existing spells; it should not change their effects or requirements.

**Jump reliability needs two separate decisions.** A jump is currently a one-shot boolean carried in the unreliable ordered movement stream, then cleared locally. If its packet is lost, later movement updates do not repeat the jump request. The client can predict a takeoff the server never receives. This is confirmed by the send path and is already acknowledged in [the architecture notes](/home/plato/codex/docs/TECHNICAL_ARCHITECTURE.md:228). It was not reproduced using injected packet loss in this review. Godot's unreliable modes do not guarantee delivery. [Godot 4.5 multiplayer transfer modes](https://docs.godotengine.org/en/4.5/tutorials/networking/high_level_multiplayer.html).

Give jump presses their own event identity. Repeat a recent unacknowledged event in subsequent movement commands, or use bounded redundant command history. The server should consume each event at most once and acknowledge consumption or rejection, expire stale requests, and invalidate them across round/reconnect boundaries. Lost acknowledgments must not cause repeat jumps. The server remains responsible for deciding whether the jump is legal.

Separately, a press shortly before landing is discarded: simulation clears `jump_queued` on the airborne tick. A small pre-landing input buffer, initially around 80–120 milliseconds, is worth an offline comparison. That range is proposed tuning, not a verified Classic mechanic. Decide explicitly whether holding Space repeats jumps; the current press-only handling does not implement that feature. Network retransmission must not silently turn into a long jump buffer.

Preserve takeoff momentum during the first pass. Do not assume that adding air steering, coyote time, or a different jump arc makes movement more faithful. Test stationary jumps, running jumps, midair turns, released movement, collision, roots, and speed changes against the specific Classic version being used as a reference.

**Control options should support familiar habits.** Add a bindable autorun toggle first. The original manual documents Num Lock for autorun, so that is a defensible optional default if unclaimed. Existing bindings should survive the addition. Suggested cancellation rules for Starfall are explicit forward/backward intervention, pressing autorun again, opening a blocking menu, focus loss, death, or leaving the session. Decide whether chat should cancel it; a conservative initial choice is cancellation. Those cancellation details are a proposed product policy, not verified manual behavior. [Blizzard manual, printed p. 20](https://bnetcmsus-a.akamaihd.net/cms/template_resource/LO0VQ46XB1281555957773363.pdf).

Offer two optional movement presets: Classic with A/D turning and Q/E strafing; Strafe with the current A/D strafing arrangement. Keep the existing custom-bind editor and its conflict handling. Applying a movement preset should not reset the hotbar or unrelated bindings. A walk toggle is useful for world movement but contributes less to arena responsiveness than the preceding fixes.

Mouse-button bindings are another worthwhile addition. The current general binding representation and held-action checks are keyboard-based, so this needs device-aware bindings, display labels, save/load support, and conflict checks. Side buttons can support autorun or another movement action without interfering with the reserved world gestures. This is a moderate feature, not just adding a mouse keycode to the current dictionary.

**Camera polish should remain optional and responsive.** Keep free look as a first-class behavior. An optional follow-while-moving mode could ease camera yaw back behind the actor after the player releases orbit; it must suspend during manual drag and never rotate the character by itself. Add a bindable recenter-camera action and a separate keyboard turn-speed setting before exposing a large menu of camera parameters.

Wheel zoom currently changes distance in 0.8-unit steps within a 3–18-unit range. Short visual easing could improve that transition. Collision response needs different treatment: move inward promptly when geometry blocks the camera, then ease outward after clearance. Test pillars, narrow gaps, walls, ramps, and extreme pitch before deciding whether the current SpringArm needs changes. There is no measured clipping failure from this review.

World clicking should also become deliberate. The inspected gameplay path provides frame clicking and keyboard targeting, but no connected actor click-selection handler was found. A small-motion click can select a visible character; a drag should orbit without changing targets. Establish a screen-space threshold and respect world occlusion. Preserve right-click focus on enemy arena frames. Blizzard documents clicking characters to target, but its right-click auto-attack behavior should not be imported implicitly into Starfall's combat rules. [Blizzard movement and targeting guide](https://worldofwarcraft.blizzard.com/en-us/news/20151231).

**Terrain and prediction need measurement before tuning.** Combatants currently use the CharacterBody3D defaults for floor speed, snap distance, and slope angle; the movement routine has no explicit step-up solver. Godot documents that its default floor mode can change speed on slopes. The arena already uses authored ramp collision, so this is a reason to measure uphill/downhill traversal and seams, not evidence that the map currently has broken stairs. [Godot 4.5 CharacterBody3D reference](https://docs.godotengine.org/en/4.5/classes/class_characterbody3d.html).

Record travel speed along the surface and horizontal progress separately. Test ramp entry, descending contact, corners, wall sliding, ledge departure, and different approach angles. If a small-step solver is needed, use the same bounded collision-aware algorithm in server simulation and client prediction. It must not permit climbing cover or bypassing arena boundaries. Increasing floor snap indiscriminately can also alter ledge and jump behavior.

Prediction already replays unacknowledged movement after authoritative snapshots and treats forced displacement separately. A remaining audit area is that replay evaluates historical movement against currently available movement/CC state. Speed changes or control effects arriving during reconciliation could produce differences that ordinary straight-line latency tests miss. This is an inspection finding requiring targeted tests, not a confirmed cause of the previously reported Windows freeze. See [movement_prediction.gd](/home/plato/codex/scripts/movement_prediction.gd:15).

**Verification and proposed completion criteria.** The existing movement/keybind suite passed **23/23**. The real localhost host/client movement scenario also passed with **150 milliseconds of injected delay in each message direction** for delayed input/action and snapshot delivery. It covers immediate local starts, reversal, strafing, stopping, jump momentum, authoritative movement, combat, rematch, and disconnect takeover. That fixed-delay scenario does not establish behavior under packet loss, jitter, reordering, or native mouse capture.

The temporary probes additionally demonstrated UI-origin camera/movement leakage, scaled mouse displacement, airborne jump-request clearing, and the stale-facing validation condition. Native Windows/Linux mouse behavior and an instrumented WoW baseline remain unmeasured.

| Proposed test | Acceptance criterion |
|---|---|
| UI-origin left/right drags and both-button presses | No world rotation or forward movement caused by the UI gesture |
| World orbit/steer handoffs, both release orders | Defined facing and movement with no phantom click or stuck capture |
| Same displacement at 1080p, 1440p, 4K, and ultrawide; every UI scale | Same intended yaw change within numerical tolerance |
| Mouse turn immediately followed by ability input | Validation uses the intended legal facing, including before the next physics tick |
| Release movement then cast; jump then cast | Consistent event ordering while preserving current spell restrictions |
| Deliberately drop the first jump command | A valid recent request reaches the server; duplicates never produce extra jumps |
| Delayed/reordered jump events, death, round change, reconnect | No stale takeoff or cross-session replay |
| Fixed latency plus 1–5% random and short-burst loss | Measure missed jumps and correction distance, not merely final position |
| Stun/root/slow expiry during prediction replay | No illegal movement; corrections recorded and explained |
| Alt-Tab, chat, settings, edit mode | No stuck movement or unintended resumption |
| Ramps, seams, corners, walls | Stable contact and legal movement on server and client |
| Physical Windows and Linux mouse sessions | Reliable capture, cursor return, and matched-DPI steering |

The loss percentages and display matrix are proposed coverage, not test results. Keep automated physics and input tests lightweight. Use short native sessions for pointer behavior and camera feel rather than expanding every visual CI suite into a benchmark.

**Recommended delivery order.** First, implement world/UI gesture ownership, unscaled sensitivity, steering-entry facing, action/input ordering, and jump event delivery. These are concrete consistency fixes with clear tests. Second, add autorun, camera recenter/follow options, optional movement presets, and world click selection. Third, evaluate jump buffering, terrain handling, and numerical tuning against a measured Classic baseline.

For that baseline, use the same Classic build, camera distance, sensitivity, and mouse DPI for every sample. Record flat-ground forward/strafe/backward travel; complete keyboard rotations; stationary and running jump time, height relative to actor size, and landing distance; left/right mouse transitions; and a rapid turn–ability–turn sequence. Compare traversal relative to actor height and arena distances before importing raw numbers. Label local, network, and visual measurements separately.

Success is a character that consistently follows input, keeps camera and facing predictable, and preserves familiar PvP movement techniques. The first pass can materially improve that without changing spell balance or waiting for new animation assets.

**Source inventory.** Blizzard Entertainment's [World of Warcraft online manual](https://bnetcmsus-a.akamaihd.net/cms/template_resource/LO0VQ46XB1281555957773363.pdf), copyright 2004, printed pp. 16 and 20, provides the historical control baseline. Blizzard's [Welcome to World of Warcraft—Basic Movement and Combat](https://worldofwarcraft.blizzard.com/en-us/news/20151231), displayed publication date June 10 without a year in the retrieved text, supports mouse steering and targeting. Neither is a numerical specification for every current Classic variant.

Godot Engine's versioned 4.5 documentation supplies the engine contracts: [InputEventMouseMotion](https://docs.godotengine.org/en/4.5/classes/class_inputeventmousemotion.html), [Viewport](https://docs.godotengine.org/en/4.5/classes/class_viewport.html), [High-level multiplayer](https://docs.godotengine.org/en/4.5/tutorials/networking/high_level_multiplayer.html), and [CharacterBody3D](https://docs.godotengine.org/en/4.5/classes/class_characterbody3d.html). Local implementation evidence comes from the linked arena/prediction files, [key_bindings.gd](/home/plato/codex/scripts/key_bindings.gd:3), [player_options.gd](/home/plato/codex/scripts/player_options.gd:72), [combatant.gd](/home/plato/codex/scripts/combatant.gd:1), [arena_layout.gd](/home/plato/codex/scripts/arena_layout.gd:1), [movement tests](/home/plato/codex/tests/movement_bindings_test.gd:1), and [network fixture](/home/plato/codex/tests/network_peer.gd:1).

**Implementation follow-through.** The controls pass implements gesture ownership, unscaled sensitivity, steering-entry alignment, action-time intent, bounded jump retries with deduplication, autorun, walk, camera recenter/follow, eased wheel zoom, optional presets, mouse bindings, character click selection, and an optional 100 ms landing buffer. The current ramps pass traversal checks in both directions; no generic step solver or slope-speed retuning was introduced. Exact Classic numerical calibration, native Windows pointer verification, and broad randomized network-loss benchmarks remain unmeasured. The original audit above is retained as baseline evidence, not a description of the updated code.
