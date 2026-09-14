extends RefCounted
## Membership barrier, NOT a ray/terrain collider. Same side of every live cloud
## may interact; a segment crossing smoke while both actors are outside is legal.
const RADIUS := 3.0
const DURATION := 6.0

static func inside(cloud: Dictionary, position: Vector3) -> bool:
	return position.distance_squared_to(cloud.position) <= RADIUS * RADIUS

static func separates(game, a, b) -> bool:
	if a == null or b == null or a == b: return false
	for owner in game.actors.values():
		var cloud: Dictionary = owner.identity.get("smoke_bomb", {})
		if owner.hp <= 0 or float(cloud.get("left", 0.0)) <= 0.0: continue
		if inside(cloud, a.position) != inside(cloud, b.position): return true
	return false

static func cast(a) -> void:
	# One fixed cloud per owner. A refreshed recast replaces it, never follows Null.
	a.identity.smoke_bomb = {"left": DURATION, "position": a.position}

static func tick(a, delta: float) -> void:
	var cloud: Dictionary = a.identity.get("smoke_bomb", {})
	if cloud.is_empty(): return
	cloud.left = maxf(0.0, float(cloud.left) - maxf(0.0, delta))
	if a.hp <= 0 or cloud.left <= 0.0: a.identity.smoke_bomb = {}
