shader_type sky;
render_mode use_debanding;

// One-time, in-memory panorama plus crisp stars. The animated celestial shell
// supplies wisps without TIME invalidating this sky's cached radiance cubemap.
uniform sampler2D baked_panorama : source_color, filter_linear, repeat_enable;
uniform bool use_baked_panorama = false;
#include "res://shaders/cosmic_sky_common.gdshaderinc"

void sky() {
	vec3 ray = normalize(EYEDIR);
	if (use_baked_panorama) {
		vec2 uv = vec2(atan(ray.x, ray.z) / TAU + 0.5, acos(clamp(ray.y, -1.0, 1.0)) / PI);
		COLOR = texture(baked_panorama, uv).rgb;
	} else {
		COLOR = cosmic_background(ray);
	}
	vec3 planet_center = normalize(planet_direction);
	float planet_mask = dot(ray, planet_center) > 0.0 ? smoothstep(planet_radius * 0.999,
		planet_radius * 1.004, length(on_disk(ray, planet_center))) : 1.0;
	float star = stars(ray, 235.0) + stars(ray + vec3(2.1, 4.7, 7.9), 490.0) * 0.65;
	COLOR += vec3(0.58, 0.66, 1.0) * star * planet_mask * smoothstep(-0.45, -0.04, ray.y);
}
