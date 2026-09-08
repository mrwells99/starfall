extends Node3D
## Celestial backdrop and the distant, decorative debris field of the Starfall arena.
## No gameplay collision or simulation state lives in this presentation layer.

const ARENA_GEOMETRY = preload("res://scripts/arena_geometry.gd")
const SKY_SHADER = preload("res://shaders/cosmic_sky.gdshader")
const BAKE_SHADER = preload("res://shaders/cosmic_sky_bake.gdshader")
const MOTION_SHADER = preload("res://shaders/cosmic_sky_motion.gdshader")
var _built := false

func build_sky() -> void:
	if _built:
		return
	_built = true
	name = "CelestialBackdrop"
	var world := WorldEnvironment.new()
	world.name = "CosmicEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_512
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9699c5")
	environment.ambient_light_energy = 0.57
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	environment.fog_enabled = true
	# Ordinary depth fog is supported by Compatibility. Its gradual onset keeps
	# nearby cover crisp, adds about 11% haze at 40m, and separates distant islands.
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("2b2240")
	environment.fog_light_energy = 0.72
	environment.fog_density = 0.40
	environment.fog_depth_begin = 12.0
	environment.fog_depth_end = 240.0
	environment.fog_depth_curve = 0.40
	environment.fog_sky_affect = 0.0
	# Bloom. Everything in this arena that matters is emissive — rune lines,
	# energy arcs, ability cues, champion trim — and without glow none of it
	# reads as light, only as brightly coloured paint.
	environment.glow_enabled = true
	environment.glow_intensity = 0.62
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.03
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	# HDR threshold: only genuinely bright surfaces bloom, so lit stone stays
	# crisp instead of the whole scene going soft.
	environment.glow_hdr_threshold = 1.35
	environment.glow_hdr_scale = 2.0
	environment.set_glow_level(3, 1.0)
	environment.set_glow_level(4, 0.7)
	environment.set_glow_level(5, 0.45)
	# A touch of tint keeps the bloom in the violet family rather than washing
	# toward white as intensities stack.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	environment.adjustment_contrast = 1.02
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "PaleStarlight"
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("e6d7ce")
	sun.light_energy = 1.40
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95.0
	sun.shadow_bias = 0.03
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "VioletNebulaFill"
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("9f83ee")
	fill.light_energy = 0.46
	fill.shadow_enabled = false
	add_child(fill)
	# Rim light from behind and above. The arena is dark and the champions are
	# dark; without a back light they read as silhouettes fused to the floor.
	var rim := DirectionalLight3D.new()
	rim.name = "HorizonRim"
	rim.rotation_degrees = Vector3(-12, 168, 0)
	rim.light_color = Color("7fd4ff")
	rim.light_energy = 0.20
	rim.light_specular = 0.7
	rim.shadow_enabled = false
	add_child(rim)
	_distant_islands()
	_sky_motion()
	if DisplayServer.get_name() != "headless":
		_bake_panorama.call_deferred(sky_material)

func _bake_panorama(sky_material: ShaderMaterial) -> void:
	# The Compatibility renderer does not expose its cached radiance to sky shaders.
	# Bake the static art once into an in-memory texture instead of evaluating noise every frame.
	var viewport := SubViewport.new()
	viewport.name = "SkyPanoramaBake"
	viewport.size = Vector2i(4096, 2048)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(4096, 2048)
	var mat := ShaderMaterial.new()
	mat.shader = BAKE_SHADER
	rect.material = mat
	viewport.add_child(rect)
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var panorama := ImageTexture.create_from_image(viewport.get_texture().get_image())
	sky_material.set_shader_parameter("baked_panorama", panorama)
	sky_material.set_shader_parameter("use_baked_panorama", true)
	viewport.queue_free()

func _sky_motion() -> void:
	# TIME in a sky shader invalidates its radiance cubemap every frame. A single
	# distant additive shell animates the visible wisps while the panorama
	# and image-based reflections remain cached. This is not a fog volume.
	var shell := MeshInstance3D.new()
	shell.name = "CelestialDrift"
	var sphere := SphereMesh.new()
	sphere.radius = 510.0
	sphere.height = 1020.0
	sphere.radial_segments = 64
	sphere.rings = 32
	shell.mesh = sphere
	var material := ShaderMaterial.new()
	material.shader = MOTION_SHADER
	material.render_priority = -100
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(shell)

func _distant_islands() -> void:
	# A few wide, fractured silhouettes replace repeated diamond-shaped debris.
	# Every depth layer is one mesh/material batch with no collision or shadows.
	var random := RandomNumberGenerator.new()
	random.seed = 409833
	var geometry = ARENA_GEOMETRY.new()
	# Hue, contrast and atmospheric perspective progress with distance rather
	# than repeating one equally dark silhouette at every scale.
	var colors := [Color("101323"), Color("1a1a2d"), Color("25233a")]
	for layer in range(3):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = colors[layer]
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 1.0
		var cluster_count := 12 + layer * 4
		for i in range(cluster_count):
			var angle := (float(i) + random.randf_range(-0.26, 0.26)) * TAU / float(cluster_count)
			var distance: float = [110.0, 190.0, 285.0][layer] + random.randf_range(-14.0, 18.0)
			var center := Vector3(cos(angle) * distance, random.randf_range(-36.0, -24.0), sin(angle) * distance)
			var width := random.randf_range(18.0, 34.0) * (1.0 + layer * 0.25)
			var depth := random.randf_range(11.0, 18.0)
			var yaw := angle + random.randf_range(-0.7, 0.7)
			var basis := Basis(Vector3.UP, yaw)
			# Overlapping shelves give the crags a broad, broken floating foundation.
			geometry.rock(mat, center, Vector3(width, 7.0, depth), yaw, Color(0.75, 0.73, 0.84), 9)
			_island_keel(geometry, mat, center, width, depth, yaw, random.randf_range(9.0, 19.0))
			geometry.rock(mat, center + basis * Vector3(width * 0.15, -3.0, -2.0),
				Vector3(width * 0.64, 6.0, depth * 0.85), yaw + 0.3, Color(0.65, 0.63, 0.73), 7)
			var crag_count := random.randi_range(6, 10)
			for j in range(crag_count):
				var offset := Vector3(random.randf_range(-0.37, 0.37) * width, 5.0, random.randf_range(-0.32, 0.32) * depth)
				var crag_height := random.randf_range(4.0, 16.0) * (1.0 + layer * 0.15)
				if j == 0:
					crag_height *= 1.5
				var crag_width := random.randf_range(4.0, 8.5)
				var tint := Color.WHITE * random.randf_range(0.68, 1.04)
				tint.a = 1.0
				geometry.rock(mat, center + basis * offset, Vector3(crag_width, crag_height, crag_width * random.randf_range(0.6, 1.1)),
					yaw + random.randf_range(-0.7, 0.7), tint, random.randi_range(5, 7))
				# Small broken shoulders interrupt the vertical profile without adding tall diamonds.
				if j % 3 == 0:
					geometry.rock(mat, center + basis * (offset + Vector3(crag_width * 0.45, 0, 0)),
						Vector3(crag_width * 0.95, crag_height * 0.48, crag_width), yaw + 0.5, tint * 0.84, 5)
	var scenery := Node3D.new()
	scenery.name = "DistantFracturedIslands"
	add_child(scenery)
	geometry.finish(scenery)
	for child in scenery.get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _island_keel(geometry, mat: Material, center: Vector3, width: float,
		depth: float, yaw: float, keel_height: float) -> void:
	# Close the decorative rock shelves from below. Broad irregular keels give
	# the silhouettes weight instead of exposing the open underside of a rock.
	var basis := Basis(Vector3.UP, yaw)
	var point := center + basis * Vector3(width * 0.07, -keel_height, depth * -0.08)
	for i in range(9):
		var a := float(i) * TAU / 9.0
		var b := float(i + 1) * TAU / 9.0
		var radius_a := 0.43 + sin(a * 3.0 + 0.7) * 0.025
		var radius_b := 0.43 + sin(b * 3.0 + 0.7) * 0.025
		var p0 := center + basis * Vector3(cos(a) * width * radius_a, 1.0, sin(a) * depth * radius_a)
		var p1 := center + basis * Vector3(cos(b) * width * radius_b, 1.0, sin(b) * depth * radius_b)
		geometry.triangle(mat, p0, point, p1, Color(0.64, 0.64, 0.73))
