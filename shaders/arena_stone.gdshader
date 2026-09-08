shader_type spatial;
render_mode cull_disabled;

uniform sampler2D slate_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stone_color : source_color = vec4(0.4, 0.4, 0.43, 1.0);
uniform float grain_scale = 1.0;
uniform float weathering = 0.5;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 weights = pow(abs(world_normal), vec3(6.0));
	weights /= max(weights.x + weights.y + weights.z, 0.001);
	vec3 p = world_pos * grain_scale * 0.24;
	vec3 tex = texture(slate_texture, p.zy).rgb * weights.x
		+ texture(slate_texture, p.xz).rgb * weights.y
		+ texture(slate_texture, p.xy).rgb * weights.z;
	ALBEDO = tex * (0.62 + stone_color.rgb * 2.5) * COLOR.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
