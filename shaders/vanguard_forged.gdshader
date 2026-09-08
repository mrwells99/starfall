shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.12,0.14,0.18,1.0);
uniform float metalness = 0.8;
varying vec3 object_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){ object_position=VERTEX; }
void fragment(){
 float pits=noise(object_position*115.0);
 float mottling=noise(object_position*24.0);
 float wear=smoothstep(0.73,0.89,pits);
 ALBEDO=base_color.rgb*mix(0.75,1.12,mottling)+wear*vec3(0.12,0.105,0.08);
 METALLIC=metalness; ROUGHNESS=mix(0.32,0.62,pits);
 float height=pits*0.0007;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 a=cross(dy,NORMAL),b=cross(NORMAL,dx);
 float determinant=dot(dx,a);
 if(abs(determinant)>0.0000001){NORMAL=normalize(NORMAL-(a*dFdx(height)+b*dFdy(height))/determinant);}
}
