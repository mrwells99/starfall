shader_type spatial;
varying vec3 crystal_position;
vec3 hash3(vec3 p){return fract(sin(vec3(dot(p,vec3(127.1,311.7,74.7)),dot(p,vec3(269.5,183.3,246.1)),dot(p,vec3(113.5,271.9,124.6))))*43758.5453);}
void vertex(){crystal_position=VERTEX;}
void fragment(){
 vec3 p=crystal_position*31.0;vec3 cell=floor(p),f=fract(p);
 float nearest=9.0,second=9.0;
 for(int x=-1;x<=1;x++){for(int y=-1;y<=1;y++){for(int z=-1;z<=1;z++){
  vec3 o=vec3(float(x),float(y),float(z));vec3 d=o+hash3(cell+o)-f;float v=dot(d,d);
  if(v<nearest){second=nearest;nearest=v;}else{second=min(second,v);}
 }}}
 float fissure=1.0-smoothstep(0.012,0.065,second-nearest);
 vec3 violet=mix(vec3(0.045,0.005,0.12),vec3(0.27,0.035,0.56),clamp(nearest,0.0,1.0));
 ALBEDO=violet;METALLIC=0.25;ROUGHNESS=0.24;
 EMISSION=violet*0.7+mix(vec3(0.52,0.055,1.0),vec3(0.88,0.51,1.0),fissure)*fissure*(2.4+sin(TIME*1.1)*0.15);
}
