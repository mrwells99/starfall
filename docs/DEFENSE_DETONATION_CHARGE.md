# Defense Detonation trigger charge and server tracking

Local implementation, September 12, 2026. No commit, push, or deployment performed.

## Player behavior

- Entering aim mode remains immediate and keeps the existing smooth camera transition.
- Pulling the trigger starts a 0.6-second charge, shown by a gold ring at the crosshair. The charge is per burst, not per bullet.
- After charging, the first shot uses the current camera aim. Remaining reserved shots retain the existing 0.13-second cadence and sample their own aim.
- Repeated trigger presses do not skip or restart the charge. Leaving aim, losing focus, being controlled, or beginning an incompatible action cancels pending fire. Canceling before the first shot spends no stacks or GCD; already committed shots are not refunded.
- Current unmodified base damage is 100 per hit under the existing health/damage scaling. Only the old misleading percentage description changed; this update does not change damage.

## Server tracking

In team/duel matches, Defense Detonation sends authenticated, ordered aim-on/off and trigger-charge messages. The server tracks all shot bodies while anyone is aiming or a burst is in flight. With nobody aiming, it stops the shot-pose/history work unless the latency fallback applies. A match without any aiming-capable kit still skips unused tracking.

Server-measured ENet round-trip time is sampled every 0.25 seconds, with a smoothed reading and sustained-duration checks:

- Steadily above 160 ms for approximately two seconds enables continuous tracking for the match.
- A brief spike does not enable it.
- After activation, sustained recovery below 140 ms for five seconds disables it. The lower recovery threshold avoids repeated switching around 160 ms.
- Any participating player's sustained high ping can enable the fallback, not only the shooter. Departed peers are removed from the policy.

World sessions retain continuous tracking because classes can arrive mid-session. Generic opt-in instant hitscan kits also retain continuous tracking because they have no trigger-charge protocol. Client-side preview geometry remains available when needed. Movement, movement collision, and normal character rendering are not paused.

Aim and charge state is tied to the owning peer, round epoch, mode serial, and motion revision. Old messages cannot reopen canceled aim. Death, ownership changes, revision changes, and teardown clear stale state. Server validation requires a started charge before accepting the initial shot, with a 50 ms arrival/frame tolerance; the normal client charges the full 0.6 seconds of simulation time. A delayed aim acknowledgment additionally waits for a usable snapshot, rather than firing against history from before tracking began.

## Validation

- Aim/latency policy: 36 checks, including spike rejection, sustained high ping, recovery, two simultaneous aimers, ownership changes, and stale intent.
- Roster gating: 108 checks across all class pairings and server/client policy branches.
- Trigger input and cancellation: 36 checks, including early clicks, full charge, multi-shot cadence, focus loss, and canceled-charge reuse prevention.
- Authoritative detonation: 67 checks covering bursts, terrain, friendly/protected bodies, camera validation, rewind, and resource protection.
- Camera/input regression: 95 checks; generic aiming: 41 checks; dedicated runtime: 67 checks.
- Real production-policy networking: 30/30 first shots hit, covering a running target, +150 ms round-trip delay, and +80 ms with 1% packet loss plus interrupted aim entry. The sustained-high-ping case used continuous tracking for 10/10 shots; the low-delay running case used it for 0/10. The lossy case switched on the fallback for 4/10 shots as server-measured RTT stayed high.
- A separate complete three-shot burst passed over +150 ms round-trip delay, preserving cadence, stack consumption, duplicate rejection, and automatic aim exit.

The earlier broader 0.5-second prototype found shot-timing expiries under jitter/loss and +200 ms added delay, also reproduced with continuous tracking. This change does not increase the existing 250 ms maximum shot age or guarantee hits under every connection condition.

Network messages changed, so the local version is 0.11.4. Client and server must use matching updated builds when the owner deploys.
