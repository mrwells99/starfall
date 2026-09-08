shader_type spatial;
render_mode cull_disabled;

// One existing slate source, five different material constructions. Profiles
// are uniform per batch, not a branch chosen separately by every fragment.
uniform sampler2D slate_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stone_color : source_color = vec4(0.4, 0.4, 0.43, 1.0);
uniform float grain_scale = 1.0;
uniform float weathering = 0.5;
uniform int surface_kind : hint_range(0, 4) = 0; // basalt, flagstone, cut tile, bronze, obsidian
uniform float relief : hint_range(0.0, 2.0) = 1.0;
uniform float vein_intensity : hint_range(0.0, 6.0) = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 view_pos;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x),
		mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x), f.y);
}
// Surface-gradient bump: differentiates height in view space, so no UV tangent
// frame is required and all three projections meet with a consistent normal.
vec3 height_normal(vec3 normal, vec3 position, float height) {
	vec3 dx = dFdx(position), dy = dFdy(position);
	vec3 r1 = cross(dy, normal), r2 = cross(normal, dx);
	float determinant = dot(dx, r1);
	vec3 gradient = (dFdx(height) * r1 + dFdy(height) * r2)
		* sign(determinant) / max(abs(determinant), 0.0000001);
	// Limit steep grazes and fade subpixel relief instead of sparkling at range.
	gradient /= max(1.0, length(gradient) / 0.48);
	float resolved = 1.0 - smoothstep(0.06, 0.22, max(length(dx), length(dy)));
	return normalize(normal - gradient * relief * resolved);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 weights = pow(abs(world_normal), vec3(6.0));
	weights /= max(weights.x + weights.y + weights.z, 0.001);
	vec3 p = world_pos * grain_scale * 0.24;
	vec3 tex = texture(slate_texture, p.zy).rgb * weights.x
		+ texture(slate_texture, p.xz).rgb * weights.y
		+ texture(slate_texture, p.xy).rgb * weights.z;
	float grain = clamp(dot(tex, vec3(0.299, 0.587, 0.114)) * 1.7, 0.0, 1.0);
	vec2 mineral_uv = world_pos.xz + world_pos.yy * vec2(0.31, 0.73);
	float mineral = noise2(mineral_uv * 0.72);
	float grit = noise2(mineral_uv * 13.0);
	vec3 albedo;
	float height;
	float roughness;
	float metal = 0.0;
	float spec = 0.28;
	if (surface_kind == 1) {
		// Worn limestone flagstones: a rubbed center and dusty, rough edges.
		vec2 slab = fract((world_pos.xz + 18.0) * 0.5);
		vec2 edge = min(slab, 1.0 - slab);
		float worn_edge = 1.0 - smoothstep(0.018, 0.12, min(edge.x, edge.y));
		float age = hash21(floor((world_pos.xz + 18.0) * 0.5));
		albedo = mix(vec3(0.48, 0.458, 0.434), vec3(0.62, 0.591, 0.54), mineral);
		albedo *= 0.60 + grain * 0.56 + age * 0.10;
		albedo = mix(albedo, vec3(0.35, 0.325, 0.30), worn_edge * 0.30);
		height = grain * 0.023 + grit * 0.002 - worn_edge * 0.018;
		roughness = mix(0.74, 0.96, worn_edge * 0.75 + (1.0-grain) * 0.25);
	} else if (surface_kind == 2) {
		// Blue cut-stone tesserae, set into narrow mortar with scored surfaces.
		vec2 tile_uv = world_pos.xz * vec2(1.15, 1.5);
		tile_uv.x += mod(floor(tile_uv.y), 2.0) * 0.5;
		vec2 cell = fract(tile_uv);
		vec2 edge = min(cell, 1.0 - cell);
		float aa = max(fwidth(tile_uv.x), fwidth(tile_uv.y));
		float mortar = 1.0-smoothstep(0.025, 0.045 + aa, min(edge.x, edge.y));
		float age = hash21(floor(tile_uv));
		albedo = mix(vec3(0.22, 0.29, 0.35), vec3(0.34, 0.44, 0.51), age);
		albedo *= 0.82 + grain * 0.42;
		albedo = mix(albedo, vec3(0.115, 0.132, 0.15), mortar * 0.72);
		height = grain * 0.020 - mortar * 0.022;
		roughness = mix(0.52 + 0.14 * grain, 0.97, mortar);
		spec = 0.38;
	} else if (surface_kind == 3) {
		// Hammered bronze. Patina lives in pits; exposed metal is smoother.
		float patina = smoothstep(0.50, 0.76, mineral + (1.0-grain) * 0.20);
		albedo = mix(vec3(0.64, 0.47, 0.235), vec3(0.16, 0.30, 0.275), patina);
		albedo *= 0.82 + grit * 0.28;
		height = grit * 0.006 + grain * 0.003;
		roughness = mix(0.32, 0.83, patina);
		metal = mix(0.62, 0.10, patina);
	} else if (surface_kind == 4) {
		// Volcanic glass and rough fracture planes below the playable island.
		float fracture = smoothstep(0.32, 0.64, grain);
		albedo = tex * vec3(0.42, 0.40, 0.65);
		height = grain * 0.043;
		roughness = mix(0.86, 0.37, fracture);
		spec = 0.44;
	} else {
		// Structural basalt keeps the source's large angular fractures.
		albedo = tex * (0.72 + stone_color.rgb * 2.3);
		albedo = mix(albedo, albedo * vec3(1.22, 1.10, 0.94), mineral * 0.23);
		height = grain * 0.046 + grit * 0.003;
		roughness = mix(0.94, 0.73, grain);
	}
	ALBEDO = albedo * COLOR.rgb;
	NORMAL = height_normal(normalize(NORMAL), view_pos, height);
	ROUGHNESS = clamp(roughness + (weathering - 0.5) * 0.2, 0.05, 1.0);
	METALLIC = metal;
	SPECULAR = spec;
	// Sparse fissure fragments, restricted to explicitly opted-in materials.
	float fissure = 1.0 - smoothstep(0.11, 0.18, grain);
	float pocket = smoothstep(0.67, 0.77, mineral);
	EMISSION = vec3(0.29, 0.045, 0.85) * fissure * pocket * vein_intensity;
}
