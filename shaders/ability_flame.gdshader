shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D flame_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 hot_color : source_color = vec4(1.0, 0.83, 0.37, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.12, 0.012, 1.0);
uniform float effect_time = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float rise = 0.18;
uniform float flame_speed = 1.0;
uniform bool black_background = false;
uniform bool on_ground = false;
varying float phase;
void vertex() {
	phase = INSTANCE_CUSTOM.r;
	float t = effect_time * flame_speed + phase * 6.28318;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 scale_v = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 local = VERTEX;
	local.x += sin(t * 4.1 + local.y * 3.0) * 0.045 * (local.y + 0.5);
	local.y *= 0.90 + 0.12 * sin(t * 2.7);
	if (!on_ground) {
		mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(center, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * facing;
		VERTEX = local * scale_v + vec3(0.0, rise * (0.5 + 0.5 * sin(t * 2.0)), 0.0);
	}
}
void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * 9.0 + effect_time * 6.0 + phase * 31.0) * 0.018 * (1.0 - uv.y);
	vec4 tex = texture(flame_texture, uv);
	float heat = max(tex.r, max(tex.g, tex.b));
	float alpha = black_background ? smoothstep(0.01, 0.13, heat) * sqrt(heat) : tex.a;
	vec3 flame = mix(edge_color.rgb, hot_color.rgb, smoothstep(0.10, 0.8, heat));
	flame = mix(flame, vec3(1.0, 0.96, 0.77), smoothstep(0.8, 1.0, heat) * 0.7);
	if (black_background) { flame = tex.rgb; }
	ALBEDO = flame;
	EMISSION = flame * (black_background ? 0.7 : (0.45 + heat * 0.9));
	ALPHA = alpha * opacity * COLOR.a;
}
