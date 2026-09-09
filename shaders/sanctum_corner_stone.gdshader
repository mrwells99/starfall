shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Authored PBR detail remains in UV space. Low-frequency world-space fields
// add intrinsic mineral/oxidation color, without painting light, AO or shadows.
// Vertex color, tangent frames, UV2 and the engine's baked GI remain intact.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float wear_amount : hint_range(0.0, 1.0) = 0.35;
uniform float material_uv_scale : hint_range(0.1, 4.0) = 1.0;
uniform float weather_base_height = 0.0;

// Optional fade is for the 12 x 14 metre upgraded floor module. It reaches
// the exact original material at every edge, without changing slab geometry.
// Supply all three original maps when enabling. Keep disabled for cover/wall.
uniform bool original_blend_enabled = false;
uniform sampler2D original_albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D original_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D original_roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 original_tint : source_color = vec4(0.4, 0.41, 0.45, 1.0);
uniform float original_normal_strength : hint_range(0.0, 2.0) = 0.65;
uniform vec2 corner_center = vec2(-6.0, 7.0);
uniform vec2 corner_half_size = vec2(6.0, 7.0);
uniform float corner_fade_width : hint_range(0.05, 5.0) = 2.0;

varying vec3 world_position;
varying vec3 world_surface_normal;

float hash3(vec3 point) {
	point = fract(point * 0.1031);
	point += dot(point, point.yzx + 33.33);
	return fract((point.x + point.y) * point.z);
}

float mineral_noise(vec3 point) {
	vec3 cell = floor(point);
	vec3 f = fract(point);
	f = f * f * (3.0 - 2.0 * f);
	float lower = mix(
		mix(hash3(cell), hash3(cell + vec3(1, 0, 0)), f.x),
		mix(hash3(cell + vec3(0, 1, 0)), hash3(cell + vec3(1, 1, 0)), f.x), f.y);
	float upper = mix(
		mix(hash3(cell + vec3(0, 0, 1)), hash3(cell + vec3(1, 0, 1)), f.x),
		mix(hash3(cell + vec3(0, 1, 1)), hash3(cell + vec3(1, 1, 1)), f.x), f.y);
	return mix(lower, upper, f.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 material_uv = UV * material_uv_scale;
	vec3 base = texture(albedo_map, material_uv).rgb * tint_color.rgb * COLOR.rgb;
	vec3 mapped_normal = texture(normal_map, material_uv).rgb;
	float rough = texture(roughness_map, material_uv).r;
	vec3 surface = normalize(world_surface_normal);
	float upper_face = smoothstep(0.3, 0.92, surface.y);
	float vertical_face = 1.0 - smoothstep(0.25, 0.85, abs(surface.y));

	// Metre-scale mineral variation is continuous between adjacent meshes and
	// deliberately independent of the repeating four-metre source texture.
	float broad = mineral_noise(world_position * 0.57 + vec3(9.1, 3.7, 1.8));
	float broken = mineral_noise(world_position * 2.35 + vec3(2.8, 7.3, 4.1));
	float mineral = smoothstep(0.34, 0.75, broad * 0.76 + broken * 0.24);

	// Long, interrupted vertical mineral streaks; never a black crack network.
	// Flat floor faces have no runoff. Skip the third 3D noise evaluation
	// there; this branch preserves the exact zero used by the original formula.
	float runoff = 0.0;
	if (vertical_face > 0.0) {
		float channels = mineral_noise(world_position * vec3(3.7, 0.16, 3.7) + vec3(5.6, 1.1, 8.3));
		runoff = smoothstep(0.52, 0.81, channels) * mix(0.4, 1.0, broad) * vertical_face;
	}
	float lower_band = (1.0 - smoothstep(0.08, 1.05, world_position.y - weather_base_height))
		* smoothstep(0.20, 0.66, broken) * vertical_face;
	float settled_dust = upper_face * smoothstep(0.26, 0.76, broad);

	// Keep the original material recognizable. At default wear, discoloration
	// remains a modest change in reflectance, while roughness keeps dust matte.
	vec3 mineral_tint = mix(vec3(0.73, 0.70, 0.64), vec3(1.16, 1.11, 0.98), mineral);
	vec3 aged = base * mix(vec3(1.0), mineral_tint, wear_amount);
	aged *= mix(vec3(1.0), vec3(0.52, 0.49, 0.42), runoff * wear_amount * 0.80);
	aged *= mix(vec3(1.0), vec3(0.48, 0.46, 0.39), lower_band * wear_amount);
	aged = mix(aged, aged * vec3(1.25, 1.20, 1.10), settled_dust * wear_amount * 0.40);
	rough = clamp(rough + wear_amount * (0.09 * runoff + 0.12 * lower_band + 0.12 * settled_dust), 0.0, 1.0);
	float map_depth = normal_strength;

	if (original_blend_enabled) {
		vec2 inside = corner_half_size - abs(world_position.xz - corner_center);
		float upgraded = smoothstep(0.0, max(corner_fade_width, 0.001), min(inside.x, inside.y));
		vec3 original_color = texture(original_albedo_map, UV).rgb * original_tint.rgb * COLOR.rgb;
		vec3 old_normal = texture(original_normal_map, UV).rgb * 2.0 - 1.0;
		vec3 new_normal = mapped_normal * 2.0 - 1.0;
		aged = mix(original_color, aged, upgraded);
		rough = mix(texture(original_roughness_map, UV).r, rough, upgraded);
		mapped_normal = normalize(mix(old_normal, new_normal, upgraded)) * 0.5 + 0.5;
		map_depth = mix(original_normal_strength, normal_strength, upgraded);
	}
	ALBEDO = aged;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	NORMAL_MAP = mapped_normal;
	NORMAL_MAP_DEPTH = map_depth;
}
