shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 energy_color : source_color = vec4(0.62,0.17,1.0,1.0);
uniform float strength = 1.25;
uniform float pulse_speed = 1.0;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed + world_pos.y * 0.4 + world_pos.x * 0.15);
	ALBEDO = energy_color.rgb * pulse * strength;
}
