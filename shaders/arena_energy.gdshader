shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform vec4 energy_color : source_color = vec4(0.62, 0.17, 1.0, 1.0);
uniform float strength = 1.25;
uniform float pulse_speed = 1.0;
uniform float emission_gain : hint_range(0.0, 8.0) = 3.4;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float phase = world_pos.y * 0.65 + world_pos.x * 0.27 + world_pos.z * 0.17;
	float pulse = 0.91 + 0.09 * sin(TIME * pulse_speed + phase);
	float current = 0.86 + 0.14 * pow(0.5 + 0.5 * sin(phase * 8.0 - TIME * 1.4), 6.0);
	ALBEDO = energy_color.rgb * 0.12;
	ROUGHNESS = 0.65;
	EMISSION = energy_color.rgb * strength * emission_gain * pulse * current;
}
