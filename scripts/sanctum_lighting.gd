extends RefCounted
## One source of truth for runtime lighting and the offline indirect bake.
const AMBIENT_COLOR := Color("8090b3")
const AMBIENT_ENERGY := 0.24
const EXPOSURE := 1.04
const DIRECTIONS := [Vector3(-42,-38,0), Vector3(-24,140,0), Vector3(-16,168,0)]
const COLORS := [Color("c9d8ee"), Color("887cc2"), Color("8cbfe2")]
const ENERGIES := [1.12, 0.12, 0.17]

static func apply_directional(light: DirectionalLight3D, index: int) -> void:
	light.rotation_degrees = DIRECTIONS[index]
	light.light_color = COLORS[index]
	light.light_energy = ENERGIES[index]
	light.light_bake_mode = Light3D.BAKE_DYNAMIC

static func add_votive_lights(parent: Node3D, scene_owner: Node = null) -> void:
	for x in [-17.25,17.25]:
		for z in [-9.0,9.0]:
			var lamp := OmniLight3D.new()
			lamp.name = "WarmVotive"
			lamp.position = Vector3(x,1.65,z)
			lamp.light_color = Color("ffc17e")
			lamp.light_energy = 1.65
			lamp.omni_range = 5.0
			lamp.omni_attenuation = 1.45
			lamp.shadow_enabled = false
			lamp.light_bake_mode = Light3D.BAKE_DYNAMIC
			parent.add_child(lamp)
			if scene_owner != null:
				lamp.owner = scene_owner
