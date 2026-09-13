extends Node3D
## Owner-selected B slipstream. Anchor at actor feet; direction is world-space.
## Three retained MultiMeshes, eighteen tapered wisps, no lights/particles/custom shaders.
## Prepared at model setup, never on cast; cosmetic state is never replicated.
const STYLE_NAMES := ["Natural airflow", "Fast slipstream", "Turbulent wake"]
const LAYERS := 3
const PER_LAYER := 6
const RIBBON_COUNT := LAYERS * PER_LAYER
const SEGMENTS := 20
const MAX_SPEED := 65.0
const BOUNDS := AABB(Vector3(-7, -7, -7), Vector3(14, 16, 14))
static var ribbon_meshes: Array[ArrayMesh] = []
static var air_material: StandardMaterial3D

var style := 1
var observer_visible := true
var reduced_effects := false
var conceal_alpha := 1.0
var _layers: Array[MultiMeshInstance3D] = []
var _poses: Array[Transform3D] = []
var _from_poses: Array[Transform3D] = []
var _alphas := PackedFloat32Array()
var _from_alphas := PackedFloat32Array()
var _seeds := PackedFloat32Array()
var _phase := ""
var _phase_age := 0.0
var _blend_age := 0.0
var _blend_duration := 0.0
var _last_speed := 0.0
var _impact_speed := 25.0
var _active_count := 0
var _local_up := Vector3.UP
var _local_direction := Vector3.FORWARD

func _init() -> void:
	name = "NullVantageWind"
	visible = false
	if ribbon_meshes.is_empty():
		for kind in LAYERS:
			ribbon_meshes.append(_build_ribbon(kind))
	if air_material == null:
		air_material = StandardMaterial3D.new()
		air_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		air_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		air_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		air_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		air_material.vertex_color_use_as_albedo = true
		air_material.albedo_color = Color(.77, .82, .85, 1.0)
	for layer in LAYERS:
		var instance := MultiMeshInstance3D.new()
		instance.name = "AirLayer%d" % layer
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		instance.material_override = air_material
		instance.multimesh = MultiMesh.new()
		instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		instance.multimesh.use_colors = true
		instance.multimesh.mesh = ribbon_meshes[layer]
		instance.multimesh.instance_count = PER_LAYER
		instance.multimesh.custom_aabb = BOUNDS
		add_child(instance)
		_layers.append(instance)
	for index in RIBBON_COUNT:
		_poses.append(Transform3D.IDENTITY)
		_from_poses.append(Transform3D.IDENTITY)
		_alphas.append(0.0)
		_from_alphas.append(0.0)
		_seeds.append(fposmod(sin(float(index + 1) * 12.9898) * 43758.5453, 1.0))
	clear()

static func _build_ribbon(kind: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bend := [.07, -.12, .19][kind] as float
	for segment in SEGMENTS:
		for side in 2:
			# Two strips meet on an opaque centerline; both outside edges are clear.
			# This softens a thin air filament without an additive glow or texture.
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
				var t := (float(segment) + corner.x) / SEGMENTS
				var across := float(side) + corner.y - 1.0
				var taper := pow(maxf(0.0, sin(t * PI)), .7)
				var curl := bend * sin(t * PI * .92) + .018 * sin(t * TAU * (1.0 + .3 * kind))
				# A few screen pixels wide at the review camera: air should read as
				# a soft wisp, not a subpixel dotted wire. Edge alpha still reaches 0.
				var width := .040 * taper
				var alpha := (1.0 - absf(across)) * smoothstep(0.0, .16, t) * (1.0 - smoothstep(.72, 1.0, t))
				surface.set_color(Color(1, 1, 1, alpha))
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(curl + across * width, .014 * sin(t * TAU), t))
	return surface.commit()

func update_effect(phase: String, elapsed: float, direction: Vector3, speed: float, delta: float) -> void:
	if not observer_visible or reduced_effects or not is_finite(conceal_alpha) or conceal_alpha <= .01 or phase not in ["lift", "dive", "recover"] or not is_finite(elapsed) or not is_finite(speed):
		if not _phase.is_empty() or visible:
			clear()
		return
	style = clampi(style, 0, STYLE_NAMES.size() - 1)
	var frame_delta := clampf(delta, 0.0, .25) if is_finite(delta) else 0.0
	var phase_time := maxf(0.0, elapsed)
	var motion_speed := clampf(speed, 0.0, MAX_SPEED)
	if phase == "recover" and phase_time >= .22:
		clear()
		return
	if phase != _phase or phase_time + .05 < _phase_age:
		if phase == "recover":
			_impact_speed = maxf(25.0, _last_speed)
		_blend_age = 0.0
		_blend_duration = (.09 if phase == "dive" else .055) if not _phase.is_empty() else 0.0
		for index in RIBBON_COUNT:
			_from_poses[index] = _poses[index]
			_from_alphas[index] = _alphas[index]
		_phase = phase
	_phase_age = phase_time
	_blend_age += frame_delta
	_last_speed = motion_speed
	# World-space travel direction makes this safe under a rotated preview parent.
	var inverse := global_basis.orthonormalized().inverse() if is_inside_tree() else basis.orthonormalized().inverse()
	_local_up = (inverse * Vector3.UP).normalized()
	_local_direction = inverse * direction.normalized() if direction.is_finite() and direction.length_squared() > .00001 else -_local_up
	_active_count = 12 if style == 0 else (18 if style == 1 else 16)
	visible = true
	for index in RIBBON_COUNT:
		if index >= _active_count:
			_write(index, _poses[index], 0.0)
		elif phase == "lift":
			_lift_wisp(index, phase_time)
		elif phase == "dive":
			_dive_wisp(index, phase_time, motion_speed)
		else:
			_recovery_wisp(index, phase_time)

func _lift_wisp(index: int, elapsed: float) -> void:
	var seed := float(_seeds[index])
	var cycle := fposmod(elapsed * (1.5 + seed * .6) + index * .381966, 1.0)
	var apex := smoothstep(.29, .5, elapsed)
	var angle := index * 2.399963 + elapsed * (.4 if style == 0 else .85)
	var frame := _frame(_local_up, 0.0)
	var radial := frame.x * cos(angle) + frame.y * sin(angle)
	var tangent := frame.x * -sin(angle) + frame.y * cos(angle)
	var turbulence := 1.0 if style == 2 else .35
	var radius := .28 + seed * .28 + apex * (.10 + seed * .12)
	var origin := _local_up * (.08 + cycle * 1.35) + radial * radius
	# Air rises beside the legs, then curls open as the launch settles at its apex.
	var axis := (_local_up * (1.0 - apex * .50) + tangent * apex * (.48 + turbulence * .30) + radial * apex * .18).normalized()
	var length := (.48 + seed * .60) * (1.15 if style == 1 else 1.0)
	var width := (.62 + seed * .40) * (1.1 if style == 2 else 1.0)
	var fade := _life_fade(cycle) * smoothstep(0.0, .07, elapsed)
	var alpha := fade * (.32 if style == 0 else .38) * (1.0 - apex * .10)
	var transform := Transform3D(_frame(axis, angle + .6).scaled_local(Vector3(width, 1.0 + turbulence * apex, length)), origin)
	_place(index, transform, alpha)

func _dive_wisp(index: int, elapsed: float, speed: float) -> void:
	var seed := float(_seeds[index])
	var strength := clampf(speed / MAX_SPEED, 0.0, 1.0)
	var cycle := fposmod(elapsed * (1.6 + strength * 2.8 + seed * .6) + index * .381966, 1.0)
	var wake := -_local_direction
	var frame := _frame(wake, 0.0)
	var turbulent := 1.0 if style == 2 else .2
	var angle := index * 2.399963 + sin(elapsed * 3.5 + seed * TAU) * .14 * turbulent
	var radial := frame.x * cos(angle) + frame.y * sin(angle)
	var radius := .24 + seed * (.34 if style == 2 else .24)
	var origin := _local_up * 1.02 + radial * radius + wake * (-.25 + cycle * .8)
	var axis := (wake + radial * sin(elapsed * 5.0 + seed * TAU) * .08 * turbulent).normalized()
	var stretch := 1.0 if style == 0 else (1.35 if style == 1 else 1.05)
	var length := lerpf(.65, 3.25, strength) * (.62 + seed * .48) * stretch
	var width := (.52 + seed * .40) * (1.3 if style == 2 else 1.0)
	var curl_scale := 1.35 if style == 2 else .85
	var alpha := _life_fade(cycle) * lerpf(.15, .40 if style == 0 else .46, strength)
	var transform := Transform3D(_frame(axis, angle).scaled_local(Vector3(width * curl_scale, 1.0, length)), origin)
	_place(index, transform, alpha)

func _recovery_wisp(index: int, elapsed: float) -> void:
	var seed := float(_seeds[index])
	var angle := index * 2.399963
	var ground := _frame(_local_up, 0.0)
	var radial := ground.x * cos(angle) + ground.y * sin(angle)
	var tangent := ground.x * -sin(angle) + ground.y * cos(angle)
	var expansion := elapsed * (3.0 + _impact_speed / 35.0)
	var origin := radial * (.30 + seed * .18 + expansion) + _local_up * (.14 + seed * .35 + elapsed * .7)
	var axis := (radial + _local_up * (.10 + seed * .16) + tangent * (.35 if style == 2 else .10)).normalized()
	var length := (.35 + seed * .50) * (1.18 if style == 1 else 1.0)
	var alpha := (1.0 - smoothstep(.015, .18, elapsed)) * (.32 if style == 0 else .38) * (.7 + seed * .3)
	var transform := Transform3D(_frame(axis, angle * .45).scaled_local(Vector3(.55 + seed * .35, 1.0, length)), origin)
	_place(index, transform, alpha)

func _place(index: int, transform: Transform3D, alpha: float) -> void:
	if _blend_duration > 0.0 and _blend_age < _blend_duration:
		var blend := smoothstep(0.0, _blend_duration, _blend_age)
		transform = _from_poses[index].interpolate_with(transform, blend)
		alpha = lerpf(float(_from_alphas[index]), alpha, blend)
	_write(index, transform, clampf(alpha, 0.0, .45))

func _write(index: int, transform: Transform3D, alpha: float) -> void:
	_poses[index] = transform
	_alphas[index] = alpha
	var layer := index / PER_LAYER
	var slot := index % PER_LAYER
	_layers[layer].multimesh.set_instance_transform(slot, transform)
	var visibility_alpha:=clampf(conceal_alpha,0.0,1.0) if is_finite(conceal_alpha) else 0.0
	_layers[layer].multimesh.set_instance_color(slot, Color(1, 1, 1, alpha * visibility_alpha))

func set_observer_visible(value: bool) -> void:
	observer_visible = value
	# Do not linger through the enemy body's fade, even after proximity detection.
	if not value and (visible or not _phase.is_empty()): clear()

func set_reduced_effects(value: bool) -> void:
	reduced_effects = value
	if value and (visible or not _phase.is_empty()): clear()

static func _frame(axis: Vector3, roll: float) -> Basis:
	var z := axis.normalized()
	var reference := Vector3.UP if absf(z.dot(Vector3.UP)) < .95 else Vector3.FORWARD
	var x := reference.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x * cos(roll) + y * sin(roll), y * cos(roll) - x * sin(roll), z)

static func _life_fade(cycle: float) -> float:
	return smoothstep(0.0, .18, cycle) * (1.0 - smoothstep(.55, 1.0, cycle))

func clear() -> void:
	visible = false
	_phase = ""
	_phase_age = 0.0
	_blend_age = 0.0
	_blend_duration = 0.0
	_last_speed = 0.0
	_impact_speed = 25.0
	_active_count = 0
	for index in _poses.size():
		_write(index, Transform3D.IDENTITY, 0.0)
		_from_poses[index] = Transform3D.IDENTITY
		_from_alphas[index] = 0.0

func reset() -> void:
	clear()

func debug_stats() -> Dictionary:
	var max_alpha := 0.0
	var max_extent := 0.0
	var finite := true
	for index in RIBBON_COUNT:
		max_alpha = maxf(max_alpha, float(_alphas[index]))
		var transform: Transform3D = _poses[index]
		finite = finite and transform.is_finite() and is_finite(float(_alphas[index]))
		if _alphas[index] > 0.0:
			max_extent = maxf(max_extent, transform.origin.length() + transform.basis.z.length() + transform.basis.x.length() * .25)
	return {"phase": _phase, "style": style, "nodes": _layers.size(), "pooled_wisps": RIBBON_COUNT, "active_wisps": _active_count, "max_alpha": max_alpha, "max_extent": max_extent, "finite": finite, "visible": visible, "speed": _last_speed, "elapsed": _phase_age}
