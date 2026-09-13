extends "res://scripts/smoke_bomb_effect.gd"
## Cosmetic departure plume and floor trail: no boundary or gameplay state.
const LIFETIME := 1.45
var travel := Vector3.FORWARD
var trail_offset := Vector3.ZERO
var trail_count := 0

func start(from: Vector3, to: Vector3) -> void:
	name = "BlindsideDepartureSmoke"
	global_position = from
	trail_offset = to - from
	trail_count = clampi(ceili(trail_offset.length() / .3), 2, 96)
	puffs.multimesh.instance_count = COUNT + trail_count
	travel = (to - from) * Vector3(1, 0, 1)
	travel = travel.normalized() if travel.length_squared() > .001 else Vector3.FORWARD
	puffs.scale = Vector3.ONE
	ring.hide()
	age = 0.0
	visible = true
	set_process(true)
	_draw_cloud()

func _process(delta: float) -> void:
	age += maxf(delta, 0.0)
	if age >= LIFETIME:
		queue_free()
		return
	_draw_cloud()

func _draw_cloud() -> void:
	# A body-height plume at the old position tapers into a short departure trail.
	# Both the plume and the floor trail stay at the cast locations, never following the actor.
	var envelope := smoothstep(0.0, .075, age) * (1.0 - smoothstep(.25, LIFETIME, age))
	var side := travel.cross(Vector3.UP)
	for i in COUNT:
		var t := float(i % 12) / 11.0
		var phase := i * 2.399963
		var spread := .25 + age * .16
		var point := travel * (t * minf(1.35, trail_offset.length())) + side * sin(phase) * spread
		point.y = .25 + float(i / 12) * .55 * (1.0 - t * .6) + age * (.3 + .08 * sin(phase))
		point += side * sin(age * 1.6 + phase) * age * .07
		var size := (.65 - t * .25) * (1.0 + age * .55)
		puffs.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point))
		var charcoal := .035 + .012 * sin(phase)
		puffs.multimesh.set_instance_color(i, Color(charcoal, charcoal + .004, charcoal + .009, envelope * (.70 - t * .2)))
	for i in trail_count:
		var t := float(i) / float(trail_count - 1)
		var phase := i * 2.399963
		var point := trail_offset * t + side * sin(phase) * (.07 + age * .035)
		point.y += .12 + age * .075
		var size := (.38 + .07 * sin(phase)) * (1.0 + age * .4)
		var index := COUNT + i
		puffs.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point))
		var charcoal := .03 + .008 * sin(phase)
		puffs.multimesh.set_instance_color(index, Color(charcoal, charcoal + .004, charcoal + .009, envelope * .65))
