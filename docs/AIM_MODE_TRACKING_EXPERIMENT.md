# Aim-only hitbox tracking: first-shot experiment

Date: 2026-09-12. Local feasibility test only; no production gameplay changes or deployment.

Historical experiment: these measurements predate the subsequently requested trigger charge and sustained-ping fallback. The current implementation is documented in [DEFENSE_DETONATION_CHARGE.md](DEFENSE_DETONATION_CHARGE.md).

## Outcome

Starting server hitbox tracking only when the server receives aim-on does **not** preserve immediate first-shot reliability with the current firing and rewind rules.

Final verified-moving-target matrix, 80 shots:

- Always tracking: **30/30** immediate first shots hit.
- Aim-only tracking: **0/30** immediate first shots hit. Every shot lacked the requested historical sample, even though aim-on had already reached the server.
- Aim-only, holding aim at least 250 ms: **20/20** first shots hit in these runs. This demonstrates a warm-up requirement, not a universal safe delay.

## Final measured matrix

Added RTT is the UDP relay's extra round-trip delay, not total measured ping; local scheduling and ENet processing add overhead. All final runs used a Godot 4.5.1 dedicated server (the project's server engine version) and a Godot 4.7.2 client.

| Tracking | Added RTT (ms) | Fire timing after aim-on | Accepted/fired | Hits | Missing history |
| --- | ---: | --- | ---: | ---: | ---: |
| Always | 0 | First eligible frame | 10/10 | 10/10 | 0/10 |
| Aim-only | 0 | First eligible frame | 0/10 | 0/10 | 10/10 |
| Always | 80 | First eligible frame | 10/10 | 10/10 | 0/10 |
| Aim-only | 80 | First eligible frame | 0/10 | 0/10 | 10/10 |
| Always | 150 | First eligible frame | 10/10 | 10/10 | 0/10 |
| Aim-only | 150 | First eligible frame | 0/10 | 0/10 | 10/10 |
| Aim-only | 80 | 250 ms minimum | 10/10 | 10/10 | 0/10 |
| Aim-only | 150 | 250 ms minimum | 10/10 | 10/10 | 0/10 |

## Method

- Two real local ENet peers, actual match scene, Outlaw shooter and a strafing Ember target initially six meters away. Scripted sinusoidal strafing replaces bot decisions; ordinary player movement simulation still runs.
- The target's authoritative position and horizontal speed are logged for every shot. The runner fails if the target does not actually move. Its sampled positions spanned approximately 0.93–0.97 meters in each case, with speeds reaching about 0.74–0.97 m/s.
- A UDP relay delays both directions, including acknowledgements. No intentional packet loss or jitter is injected.
- Every trial starts out of aim, after the previous camera transition completely ends. A test setup message replenishes one Defense Detonation stack, health, and the global cooldown. Only one shot is fired.
- The normal camera starts looking at chest height. The test opens the real Defense Detonation aim mode, steers the ordinary shoulder camera at the target, then clicks at the first visible/eligible reticle frame or after the specified hold. No fabricated camera origin, selected-target hit request, or weakened validation.
- Immediate shots were submitted **56–71 ms** after activation. The 250 ms hold resulted in actual submissions **262–271 ms** after activation.
- Aim-on/off messages use the same reliable ordered channel as firing. The server owns the active-aim set. When nobody aims, the test helper skips hitbox pose updates and history collection but keeps simulation time and snapshot aim timestamps advancing. Ordinary actor movement continues. When someone aims, all actors' hitboxes resume tracking.
- The always-tracking control uses the same messages and setup but never stops collecting history.
- All 80 actual submitted rays intersected the target's current client-side aimed hitbox. The server independently performed its unchanged historical camera validation, terrain/body trace, and damage calculation. Only authoritative damage counted as a hit.

## Why immediate shots fail

The shot timestamp comes from a previously received server snapshot, with the normal additional interpolation allowance. That timestamp can precede the server receiving aim-on. Recording an actor now cannot recreate its missing past pose.

Camera validation also samples the shooter's historical root. It therefore rejects these shots before the damage trace with “Camera shot is blocked,” despite no actual wall obstruction. One +150 ms aim-only shot also exceeded the existing 250 ms timing ceiling, which is checked first; that shot lacked history too. The other 29 gated immediate shots reached and failed camera validation.

Aim-only history began approximately:

- **19–42 ms too late** with no added RTT.
- **112–135 ms too late** with +80 ms RTT.
- **169–204 ms too late** with +150 ms RTT.

The 250 ms hold supplied enough history for all 20 tested shots, but the narrowest remaining history margin at +150 ms was only about **6 ms**. It is not a guaranteed safe fixed wait for all connections.

## Interpretation and limits

The notification itself is not the observed reliability problem; the missing history is. Keeping some background history or adding an explicit history-ready warm-up would require a separately designed implementation. Merely delaying damage while retaining the original timestamp cannot reconstruct history that was never recorded.

Do not ship the bare gate. A warm-up changes how soon the first shot can register. These results do not establish a CPU saving, a universal safe warm-up, behavior under packet loss, or correctness for fast dodges/jumps/teleports. Pausing the pose animation clock can also change animation phase on resumption and needs separate handling before production use.

Initial exploratory runs used a stationary target because the synthetic roster entry retained human ownership, preventing scripted bot input. Instrumentation caught this, the fixture was corrected, and the entire final 80-shot matrix above was rerun with verified motion. Earlier stationary counts are excluded from the final results.

## Reproduce

The commands below record the original experiment setup. The current runner now includes the implemented trigger charge; use `--production --hold 0` to test the current aim/ping policy, rather than treating a rerun as identical to these historical measurements.

Set GODOT to the client executable; optionally set GODOT_SERVER to the dedicated-server executable.

```text
python tests/run_aim_mode_tracking_probe.py --trials 10 --rtt 150
python tests/run_aim_mode_tracking_probe.py --trials 10 --rtt 150 --gated
python tests/run_aim_mode_tracking_probe.py --trials 10 --rtt 150 --gated --hold 250
```

The runner uses ports 53206/53207, cleans up its owned processes, prints each shot diagnostic and summary, and fails on infrastructure/script errors or absent target motion. Shot rejection is a measured outcome, not an infrastructure error.

Only the test scripts load the experimental helper; production scenes do not reference it. Full final per-shot data is saved locally in [aim_mode_tracking_moving_results.json](C:/Users/aidan/.codex/visualizations/2026/09/12/01a093a7-a40e-7a73-81c8-ac42a296d9bd/aim_mode_tracking_moving_results.json).
