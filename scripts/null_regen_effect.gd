extends Node3D
## Small retained cross sprites drifting upward inside a player-local cylinder.
const CROSS_COUNT := 10
static var cross_mesh: ArrayMesh
static var glow_texture: GradientTexture2D
var motes: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var intensity := 0.0
var was_active := false
var observer_visible := true
var glow: MeshInstance3D
var glow_material: StandardMaterial3D
var light: OmniLight3D

func _init() -> void:
	name = "NullRegenEffect"
	visible = false
	rng.randomize()
	if cross_mesh == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Three non-overlapping rectangles form a clean medical cross.
		for rect in [Rect2(-.028, -.09, .056, .18), Rect2(-.09, -.028, .062, .056), Rect2(.028, -.028, .062, .056)]:
			for corner in [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(0,1)]:
				var point: Vector2 = rect.position + corner * rect.size
				surface.add_vertex(Vector3(point.x, point.y, 0))
		cross_mesh = surface.commit()
	for i in CROSS_COUNT:
		var sprite := MeshInstance3D.new()
		sprite.mesh = cross_mesh
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := _sprite_material()
		material.albedo_color = Color(.3, 1.0, .48, 0)
		sprite.material_override = material
		add_child(sprite)
		motes.append({"sprite":sprite, "material":material, "age":0.0, "life":2.5, "origin":Vector3.ZERO, "rise":.5})
	if glow_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0, .35, 1])
		gradient.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,.45), Color(1,1,1,0)])
		glow_texture = GradientTexture2D.new()
		glow_texture.gradient = gradient
		glow_texture.width = 64
		glow_texture.height = 64
		glow_texture.fill = GradientTexture2D.FILL_RADIAL
		glow_texture.fill_from = Vector2(.5,.5)
		glow_texture.fill_to = Vector2(1,.5)
	glow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.65, 2.2)
	glow.mesh = quad
	glow.position.y = .95
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_material = _sprite_material()
	glow_material.albedo_texture = glow_texture
	glow_material.albedo_color = Color(.2, 1, .38, 0)
	glow.material_override = glow_material
	add_child(glow)
	light = OmniLight3D.new()
	light.position.y = .9
	light.light_color = Color(.35, 1, .5)
	light.light_energy = 0
	light.omni_range = 1.8
	light.shadow_enabled = false
	add_child(light)

func _sprite_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material

func _spawn(mote: Dictionary, delay: float = 0.0) -> void:
	var angle := rng.randf_range(0, TAU)
	var radius := rng.randf_range(.42, .7)
	mote.origin = Vector3(cos(angle) * radius, rng.randf_range(.15, 1.15), sin(angle) * radius)
	mote.life = rng.randf_range(2.2, 3.0)
	mote.rise = rng.randf_range(.45, .65)
	mote.age = -delay
	mote.sprite.scale = Vector3.ONE * rng.randf_range(.75, 1.15)

func update(actor: CharacterBody3D, delta: float, conceal_alpha: float) -> void:
	# Null's pot keeps its slower, lingering six-second regeneration presentation.
	var active: bool = actor.hp > 0 and float(actor.identity.get("null_regen", {}).get("left", 0)) > 0
	_update_effect(actor, delta, conceal_alpha, active, .65)

func update_mend(actor: CharacterBody3D, delta: float) -> void:
	# Mend is visual for exactly its cast: every character shares this effect,
	# while its healing rules remain entirely in the authoritative spell code.
	var active: bool = actor.hp > 0 and actor.casting >= 0 and actor.casting < actor.kit.size() and actor.kit[actor.casting].kind == "self_heal"
	_update_effect(actor, delta, 1.0, active, .18)

func _update_effect(actor: CharacterBody3D, delta: float, conceal_alpha: float, active: bool, fade_seconds: float) -> void:
	if active and not was_active:
		for i in motes.size(): _spawn(motes[i], i * .16)
	was_active = active
	intensity = move_toward(intensity, 1.0 if active else 0.0, maxf(0,delta) / fade_seconds)
	visible = observer_visible and actor.hp > 0 and intensity > .001 and conceal_alpha > .01
	var strength := intensity * conceal_alpha
	glow_material.albedo_color.a = strength * .085
	light.light_energy = strength * .32 if visible else 0.0
	for mote in motes:
		mote.age += maxf(0,delta)
		if mote.age >= mote.life and active: _spawn(mote)
		var progress := clampf(float(mote.age) / float(mote.life), 0, 1)
		# Ease each cross in/out over most of its lifetime, with a slow steady rise.
		var fade := smoothstep(0, .35, progress) * (1.0 - smoothstep(.55, 1, progress))
		mote.sprite.position = mote.origin + Vector3.UP * float(mote.rise) * progress
		mote.material.albedo_color.a = fade * strength * .75

func set_observer_visible(value: bool) -> void:
	observer_visible = value
	if not value:
		visible = false
		light.light_energy = 0.0
