shader_type spatial;
render_mode cull_disabled, shadows_disabled, blend_add, depth_draw_never;

varying float warmth;
varying float lifetime;

void vertex() {
	float seed = INSTANCE_CUSTOM.r;
	float speed = 0.018 + INSTANCE_CUSTOM.g * 0.017;
	lifetime = fract(TIME * speed + seed);
	warmth = INSTANCE_CUSTOM.b;
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	center.y += lifetime * 8.0;
	center.x += sin(TIME * 0.31 + seed * 63.0) * 0.18;
	center.z += cos(TIME * 0.26 + seed * 47.0) * 0.18;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
	VERTEX = view_center + vec3(VERTEX.xy * size, 0.0);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, 1.45);
	float spark = pow(max(0.0, 1.0 - dot(p, p)), 3.0);
	float fade = smoothstep(0.0, 0.12, lifetime) * (1.0 - smoothstep(0.70, 1.0, lifetime));
	ALBEDO = vec3(0.0);
	EMISSION = mix(vec3(0.40, 0.22, 0.95), vec3(1.0, 0.58, 0.22), warmth) * 3.8;
	ALPHA = spark * fade * 0.72;
}
