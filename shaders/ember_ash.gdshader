shader_type spatial;
render_mode cull_disabled;
uniform float dissolve : hint_range(0,1) = 0.0;
uniform float spirit : hint_range(0,1) = 0.0;
uniform float opacity : hint_range(0,1) = 1.0;
uniform float fall : hint_range(0,1) = 0.0;
varying vec3 local_pos;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex() {
	local_pos = VERTEX;
	float grain = hash(floor(VERTEX*16.0));
	VERTEX.y -= fall*fall*(0.25+grain*0.8);
	VERTEX.xz += (vec2(grain,hash(floor(VERTEX.zyx*18.0)))-.5)*fall*.4;
}
void fragment() {
	float grain = hash(floor(local_pos*30.0));
	if (grain < dissolve) { discard; }
	float flicker = .5+.5*sin(local_pos.y*18.0-TIME*8.0+grain*5.0);
	ALBEDO = mix(vec3(.16,.14,.13)+vec3(grain*.15),vec3(1.0,.31,.055),spirit);
	EMISSION = mix(vec3(.13,.025,.005)*step(.8,grain),vec3(1.0,.17,.018)*(.45+flicker),spirit);
	ROUGHNESS = .96;
	ALPHA = opacity;
}
