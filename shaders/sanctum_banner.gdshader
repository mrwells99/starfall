shader_type spatial;
render_mode cull_disabled;

// One batched mesh, anchored at UV.y = 0. Movement takes place only in art.
uniform vec4 cloth_color : source_color = vec4(0.13, 0.065, 0.23, 1.0);
uniform vec4 thread_color : source_color = vec4(0.61, 0.41, 0.21, 1.0);
varying float wind;

void vertex() {
	float phase = VERTEX.x * 0.43 + VERTEX.z * 0.27;
	float drop = UV.y * UV.y;
	wind = sin(TIME * 0.83 + phase - UV.y * 4.5);
	VERTEX += NORMAL * drop * (wind * 0.19 + sin(TIME * 1.37 + phase + UV.x * 6.0 - UV.y * 9.0) * 0.055);
	VERTEX.y += drop * sin(TIME * 0.83 + phase - UV.y * 4.5 + 0.7) * 0.045;
}

float line(float distance_to_line, float width) {
	return 1.0 - smoothstep(width, width + max(fwidth(distance_to_line), 0.001), distance_to_line);
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 1.25, (UV.y - 0.43) * 2.8);
	float diamond = abs(abs(p.x) + abs(p.y) * 0.54 - 0.29);
	float crest = line(diamond, 0.015) * step(UV.y, 0.69);
	float axis = line(abs(p.x), 0.011) * step(abs(p.y), 0.59);
	float eye = line(abs(length(p * vec2(1.0, 1.45)) - 0.095), 0.010);
	float borders = line(abs(abs(UV.x - 0.5) - 0.431), 0.009);
	float hem = line(abs(UV.y - 0.945), 0.008);
	float thread = clamp(crest + axis + eye + borders + hem, 0.0, 1.0);
	// Subtle coarse weave is analytic, so no image or extra texture fetches.
	float weave = sin(UV.x * 460.0) * sin(UV.y * 980.0);
	float weave_visibility = 1.0 - smoothstep(0.003, 0.012, max(fwidth(UV.x), fwidth(UV.y)));
	float folds = 0.91 + 0.09 * cos(UV.x * 18.0 + wind * 0.35);
	ALBEDO = mix(cloth_color.rgb * folds * (1.0 + weave * weave_visibility * 0.065), thread_color.rgb, thread);
	ROUGHNESS = mix(0.94, 0.62, thread);
	SPECULAR = 0.20;
	// Only the central sigil glows; the decorative embroidery remains metal.
	EMISSION = vec3(0.62, 0.34, 0.93) * (eye + axis * 0.22) * 2.8;
}
