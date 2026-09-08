shader_type spatial;
render_mode cull_disabled;

varying vec3 local_position;

void vertex() {
	float seed = INSTANCE_CUSTOM.r * 6.283185;
	float angle = sin(TIME * 0.12 + seed) * 0.10;
	mat2 rotation = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	VERTEX.xz = rotation * VERTEX.xz;
	NORMAL.xz = rotation * NORMAL.xz;
	VERTEX.y += sin(TIME * 0.24 + seed) * 0.18;
	local_position = VERTEX;
}

void fragment() {
	float strata = sin(local_position.y * 32.0 + sin(local_position.x * 7.0) + local_position.z * 1.9);
	ALBEDO = mix(vec3(0.065, 0.049, 0.105), vec3(0.14, 0.12, 0.20), strata * 0.25 + 0.5) * COLOR.rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.18;
	float fissure = abs(local_position.x + sin(local_position.y * 6.0 + local_position.z * 3.0) * 0.035);
	float vein = 1.0 - smoothstep(0.008, 0.020, fissure);
	EMISSION = vec3(0.34, 0.095, 0.72) * vein * 2.7;
}
