shader_type spatial;
render_mode cull_disabled;

uniform vec4 cloth_color : source_color = vec4(0.2, 0.45, 0.6, 1.0);
uniform float movement = 0.0;

void vertex() {
	// Shoulders stay pinned. Only the lower cloth receives the breeze/stride.
	float anchor = UV.y * UV.y;
	VERTEX.z += anchor * (0.012 + movement * 0.025) * sin(TIME * 3.2 + UV.x * 7.0 - UV.y * 4.0);
	VERTEX.x += anchor * 0.009 * sin(TIME * 2.1 + UV.y * 5.0);
}

void fragment() {
	vec2 thread_uv = UV * vec2(190.0, 240.0);
	// Fade the weave below pixel scale instead of shimmering at game distance.
	float weave_visibility = 1.0 - smoothstep(0.35, 0.9, max(fwidth(thread_uv.x), fwidth(thread_uv.y)));
	float weave = sin(thread_uv.x * 6.283185) * sin(thread_uv.y * 6.283185);
	float border = 1.0 - smoothstep(0.018, 0.025, min(UV.x, 1.0 - UV.x));
	border = max(border, smoothstep(0.955, 0.965, UV.y));
	ALBEDO = mix(cloth_color.rgb * (0.96 + weave * 0.04 * weave_visibility), cloth_color.rgb * 0.55, border);
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
}
