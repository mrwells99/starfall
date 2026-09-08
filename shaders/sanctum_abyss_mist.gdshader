shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Three thin, low-opacity sheets below the arena, not volumetric fog.
varying vec3 position_world;
float hash21(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float noise(vec2 p) {
	vec2 cell=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(cell),hash21(cell+vec2(1,0)),f.x),
		mix(hash21(cell+vec2(0,1)),hash21(cell+vec2(1,1)),f.x),f.y);
}
void vertex() {
	position_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p=position_world.xz*.021+vec2(TIME*.004,-TIME*.002);
	float cloud=noise(p)*.7+noise(p*2.3)*.3;
	float radial=length(position_world.xz);
	float edge=smoothstep(29.0,48.0,radial)*(1.0-smoothstep(135.0,185.0,radial));
	ALBEDO=mix(vec3(.075,.10,.19),vec3(.20,.24,.36),cloud);
	ALPHA=edge*smoothstep(.26,.72,cloud)*.12;
}
