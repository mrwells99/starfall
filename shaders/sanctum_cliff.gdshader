shader_type spatial;
render_mode cull_disabled;

uniform sampler2D slate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 rock_color : source_color = vec4(0.19,0.23,0.30,1.0);
uniform float strata_scale = 0.64;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 view_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	view_position = (MODELVIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= max(dot(weights,vec3(1.0)),0.001);
	vec3 p = world_position * 0.15;
	vec3 grain = texture(slate,p.zy).rgb*weights.x + texture(slate,p.xz).rgb*weights.y + texture(slate,p.xy).rgb*weights.z;
	float stratum = 0.5+0.5*sin(world_position.y*strata_scale + sin(world_position.x*.19)*.6 + sin(world_position.z*.23)*.4);
	float seam = smoothstep(.70,.94,stratum);
	float height = grain.r*.11 - seam*.035;
	vec3 dx = dFdx(view_position), dy = dFdy(view_position);
	vec3 r1 = cross(dy,NORMAL), r2 = cross(NORMAL,dx);
	float det = dot(dx,r1);
	vec3 gradient = (dFdx(height)*r1+dFdy(height)*r2)*sign(det)/max(abs(det),.000001);
	gradient /= max(1.0,length(gradient)/.4);
	NORMAL = normalize(NORMAL-gradient);
	ALBEDO = rock_color.rgb * (0.72 + grain*1.1) * mix(1.0,.63,seam) * COLOR.rgb;
	ROUGHNESS = mix(.91,.76,grain.r);
	SPECULAR = .23;
}
