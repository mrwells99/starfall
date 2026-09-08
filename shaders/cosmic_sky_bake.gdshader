shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/cosmic_sky_common.gdshaderinc"

void fragment() {
	float longitude = (UV.x - 0.5) * TAU;
	float latitude = UV.y * PI;
	vec3 ray = vec3(sin(longitude) * sin(latitude), cos(latitude), cos(longitude) * sin(latitude));
	vec3 linear_color = cosmic_background(ray);
	COLOR = vec4(linear_color, 1.0);
}
