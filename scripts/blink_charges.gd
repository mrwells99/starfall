extends RefCounted
const Kits = preload("res://scripts/kits.gd")

static func tick(actor, slot: int, delta: float) -> void:
	if actor.identity.blink_charges >= Kits.BLINK_MAX_CHARGES:
		actor.cooldowns[slot] = 0.0
		return
	actor.cooldowns[slot] -= delta
	while actor.cooldowns[slot] <= 0 and actor.identity.blink_charges < Kits.BLINK_MAX_CHARGES:
		actor.identity.blink_charges += 1
		actor.cooldowns[slot] += float(actor.kit[slot].cd)
	if actor.identity.blink_charges == Kits.BLINK_MAX_CHARGES:
		actor.cooldowns[slot] = 0.0

static func spend(actor, slot: int) -> bool:
	if actor.identity.blink_charges <= 0:
		return false
	if actor.identity.blink_charges == Kits.BLINK_MAX_CHARGES:
		actor.cooldowns[slot] = actor.kit[slot].cd
	actor.identity.blink_charges -= 1
	return true

static func direction(actor, camera_yaw: Variant = null) -> Vector3:
	if actor.move_input.length() > .01:
		return (actor.basis * Vector3(actor.move_input.x, 0, actor.move_input.y)).normalized()
	var yaw: float = actor.rotation.y if camera_yaw == null else float(camera_yaw)
	return Basis(Vector3.UP, wrapf(yaw, -PI, PI)) * Vector3.FORWARD
