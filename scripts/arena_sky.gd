extends Node3D
## Celestial backdrop and the distant, decorative debris field of the Starfall arena.
## No gameplay collision or simulation state lives in this presentation layer.

const ARENA_GEOMETRY = preload("res://scripts/arena_geometry.gd")
const SKY_SHADER = preload("res://shaders/cosmic_sky.gdshader")
const BAKE_SHADER = preload("res://shaders/cosmic_sky_bake.gdshader")
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
	environment.fog_light_color = Color("201336")
	environment.fog_light_energy = 0.65
	environment.fog_density = 0.00085
	environment.fog_sky_affect = 0.0
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
	_distant_islands()
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

func _distant_islands() -> void:
	# A few wide, fractured silhouettes replace repeated diamond-shaped debris.
	# Every depth layer is one mesh/material batch with no collision or shadows.
	var random := RandomNumberGenerator.new()
	random.seed = 409833
	var geometry = ARENA_GEOMETRY.new()
	var colors := [Color("131020"), Color("211731"), Color("302043")]
	for layer in range(3):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
			geometry.rock(mat, center + basis * Vector3(width * 0.15, -3.0, -2.0),
				Vector3(width * 0.64, 6.0, depth * 0.85), yaw + 0.3, Color(0.65, 0.63, 0.73), 7)
			var crag_count := random.randi_range(6, 10)
			for j in range(crag_count):
				var offset := Vector3(random.randf_range(-0.37, 0.37) * width, 5.0, random.randf_range(-0.32, 0.32) * depth)
				var crag_height := random.randf_range(6.0, 24.0) * (1.0 + layer * 0.15)
				var crag_width := random.randf_range(3.0, 6.5)
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
