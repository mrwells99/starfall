extends RefCounted
## Default High presentation profile. The actual renderer is checked after any fallback.
## Kept independent of the bake/key light, which remains the live lighting source.

static func apply(root: Node, high: bool) -> bool:
	var capable := RenderingServer.get_current_rendering_method() == "forward_plus"
	var enabled := high and capable
	var world := root.find_child("CosmicEnvironment", true, false) as WorldEnvironment
	if world == null:
		return false
	var environment := world.environment
	environment.ssao_enabled = enabled
	environment.ssao_radius = 0.65
	environment.ssao_intensity = 1.35
	environment.ssao_power = 1.25
	environment.ssao_light_affect = 0.12
	environment.ssil_enabled = enabled
	environment.ssil_radius = 2.0
	environment.ssil_intensity = 0.35
	environment.ssil_sharpness = 0.98
	# Baked GI handles this static map. SDFGI/SSR would add cost or reflection
	# instability without addressing a current need; the corner uses one probe.
	environment.volumetric_fog_enabled = enabled
	environment.volumetric_fog_density = 0.004 if enabled else 0.0
	environment.volumetric_fog_length = 64.0
	environment.volumetric_fog_albedo = Color("768298")
	environment.volumetric_fog_ambient_inject = 0.15
	environment.volumetric_fog_sky_affect = 0.0
	environment.glow_intensity = 0.38 if enabled else 0.62
	environment.glow_bloom = 0.0 if enabled else 0.03
	environment.adjustment_saturation = 1.0 if enabled else 1.08
	var sky_material := environment.sky.sky_material as ShaderMaterial
	sky_material.set_shader_parameter("backdrop_exposure", 0.68 if enabled else 1.0)
	sky_material.set_shader_parameter("backdrop_saturation", 0.78 if enabled else 1.0)
	root.get_viewport().msaa_3d = Viewport.MSAA_2X if enabled else Viewport.MSAA_DISABLED
	return enabled
