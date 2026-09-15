extends SceneTree
const Quality = preload("res://scripts/map_image_quality.gd")
const Profiles = preload("res://scripts/sanctum_graphics.gd")
const Config = preload("res://scripts/user_config.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var art := Node3D.new()
	art.name = "CosmicSanctum"
	fixture.add_child(art)
	var world := WorldEnvironment.new()
	world.name = "CosmicEnvironment"
	world.environment = Environment.new()
	world.environment.sky = Sky.new()
	var sky := ShaderMaterial.new()
	sky.shader = Shader.new()
	sky.shader.code = "shader_type sky; uniform float backdrop_exposure = 1.0; uniform float backdrop_saturation = 1.0; void sky(){COLOR=vec3(0.0);}"
	world.environment.sky.sky_material = sky
	fixture.add_child(world)
	var map_mesh := MeshInstance3D.new()
	map_mesh.mesh = load("res://assets/environment/slice/meshes/Cover/Basalt_geometry.res")
	map_mesh.lod_bias = .5
	var stone := ShaderMaterial.new()
	stone.shader = load("res://shaders/sanctum_corner_stone.gdshader")
	map_mesh.material_override = stone
	art.add_child(map_mesh)
	var bronze := StandardMaterial3D.new()
	bronze.normal_enabled = true
	bronze.normal_scale = 1.1
	bronze.normal_texture = load("res://assets/environment/corner/textures/bronze_normal.png")
	var trim := MeshInstance3D.new()
	trim.mesh = BoxMesh.new()
	trim.material_override = bronze
	art.add_child(trim)
	var actor := MeshInstance3D.new()
	actor.mesh = BoxMesh.new()
	actor.material_override = bronze.duplicate()
	fixture.add_child(actor)
	var original_mesh := map_mesh.mesh
	for preset in ["Balanced", "High", "High", "Balanced", "Performance", "High", "Balanced"]:
		Profiles.apply_profile(fixture, preset)
		var high: bool = preset == "High"
		check(bool(stone.get_shader_parameter("stable_detail")) == high, preset + " selects only its map filter")
		check(is_equal_approx(map_mesh.lod_bias, 1.0 if high else .5), preset + " restores exact original LOD")
		check(is_equal_approx(bronze.normal_scale, .88 if high else 1.1), preset + " restores original trim strength without accumulating")
		check(is_equal_approx(actor.material_override.normal_scale, 1.1), "Actor material is untouched")
		check(map_mesh.mesh == original_mesh, "No authored geometry is replaced")
		check(not root.use_taa, "Temporal blur/trails are not enabled")
		check(not world.environment.ssil_enabled, "Baked map lighting is not duplicated by a screen-space bounce pass")
		check(root.msaa_3d == (Viewport.MSAA_4X if high else (Viewport.MSAA_DISABLED if preset == "Performance" else Viewport.MSAA_2X)), preset + " selects intended edge AA")
	check(is_equal_approx(Quality.supersample_scale(1, Vector2i(2560,1440), true),1.10), "Optimized High samples 1440p at 110 percent")
	check(is_equal_approx(Quality.supersample_scale(1, Vector2i(3840,2160), true),1), "4K output does not exceed extra pixel budget")
	check(is_equal_approx(Quality.supersample_scale(.75, Vector2i(2560,1440), true),.75), "Explicit lower resolution is respected")
	check(is_equal_approx(Quality.supersample_scale(1, Vector2i(2560,1440), false),1), "Balanced native remains native")
	Quality.apply(art, true)
	check(bool(stone.get_shader_parameter("stable_detail")), "Art-root initialization applies High detail too")
	Quality.apply(art, false)
	fixture.queue_free()
	await process_frame
	print("Map image quality checks: %d passed / %d total" % [checks-failures, checks])
	quit(1 if failures else 0)
