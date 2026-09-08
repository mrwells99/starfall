shader_type spatial;
uniform float damage_flash = 0.0;
uniform float defeated = 0.0;
uniform vec4 base_color : source_color = vec4(0.12,0.14,0.18,1.0);
uniform float metalness = 0.8;
// Frequency of the fine pit/scratch noise. Default 115 matches the previous
// character study look; lower values (~40) produce a smoother forged surface
// suitable for hero props inspected up close.
uniform float pit_frequency : hint_range(20.0, 200.0) = 115.0;
uniform float mottle_frequency : hint_range(5.0, 80.0) = 24.0;
uniform float wear_strength : hint_range(0.0, 1.0) = 1.0;
varying vec3 object_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){ object_position=VERTEX; }
void fragment(){
 float pits=noise(object_position*pit_frequency);
 float mottling=noise(object_position*mottle_frequency);
 float wear=smoothstep(0.73,0.89,pits)*wear_strength;
 ALBEDO=base_color.rgb*mix(0.80,1.10,mottling)+wear*vec3(0.10,0.09,0.075);
 METALLIC=metalness; ROUGHNESS=mix(0.36,0.58,pits);
 float height=pits*0.0007;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 a=cross(dy,NORMAL),b=cross(NORMAL,dx);
 float determinant=dot(dx,a);
 if(abs(determinant)>0.0000001){NORMAL=normalize(NORMAL-(a*dFdx(height)+b*dFdy(height))/determinant);}
 ALBEDO = mix(ALBEDO, vec3(0.85, 0.9, 1.0), damage_flash * 0.8);
 ALBEDO *= mix(1.0, 0.3, defeated);
 EMISSION *= 1.0 - defeated * 0.85;
}
