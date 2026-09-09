shader_type sky;
render_mode use_debanding;

// One-time, in-memory panorama plus crisp stars. The animated celestial shell
// supplies wisps without TIME invalidating this sky's cached radiance cubemap.
uniform sampler2D baked_panorama : source_color, filter_linear, repeat_enable;
uniform bool use_baked_panorama = false;
uniform float backdrop_exposure = 1.0;
uniform float backdrop_saturation = 1.0;
uniform vec3 sun_direction = vec3(-0.457, 0.669, 0.586);
uniform float sun_angular_radius = 0.12;
#include "res://shaders/cosmic_sky_common.gdshaderinc"

vec3 visible_sun(vec3 ray, vec3 background) {
	vec3 center = normalize(sun_direction);
	if (dot(ray, center) <= 0.0) {
		return background;
	}
	vec2 disk = on_disk(ray, center) / sin(sun_angular_radius);
	float radius = length(disk);
	float outside = max(radius - 1.0, 0.0);
	// Broad, restrained corona and finer rays distinguish the star from a planet.
	float angle = atan(disk.y, disk.x);
	float rays = pow(0.5 + 0.5 * sin(angle * 11.0 + sin(angle * 5.0) * 1.6), 6.0);
	float corona = exp(-outside * 9.0) * 0.30
		+ exp(-outside * 3.0) * 0.07 + rays * exp(-outside * 5.0) * 0.10;
	vec3 halo = vec3(1.0, 0.63, 0.26) * corona;
	if (radius > 1.02) {
		return background + halo;
	}
	float limb = sqrt(max(0.0, 1.0 - radius * radius));
	float granules = noise3(vec3(disk * 42.0, 4.7));
	float convection = fbm(vec3(disk * 7.0, 9.3));
	vec3 photosphere = mix(vec3(1.6, 0.92, 0.36), vec3(2.8, 2.55, 2.12), pow(limb, 0.45));
	photosphere *= 0.86 + convection * 0.18 + granules * 0.09;
	float coverage = 1.0 - smoothstep(0.994, 1.004, radius);
	return mix(background + halo, photosphere + halo * 0.25, coverage);
}

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
	COLOR = mix(vec3(dot(COLOR, vec3(0.2126, 0.7152, 0.0722))), COLOR,
		backdrop_saturation) * backdrop_exposure;
	// The existing directional light already supplies sunlight and baked bounce.
	// Keep this visible disc out of the ambient radiance bake to avoid double lighting.
	if (!AT_CUBEMAP_PASS) {
		COLOR = visible_sun(ray, COLOR);
	}
}
