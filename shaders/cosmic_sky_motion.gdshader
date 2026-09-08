shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, fog_disabled;

// One low-detail shell behind the scenery. Analytic currents run in the vertex
// stage; all expensive nebula noise stays in the one-time bake.
#include "res://shaders/cosmic_sky_common.gdshaderinc"

varying vec3 world_position;
varying vec3 drift_light;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 ray = normalize(world_position);
	float sky_mask = smoothstep(-0.40, -0.025, ray.y);

	// Long, slow currents drift in opposite directions, without moving the
	// planet or landmarks. Their brightness stays below gameplay effects.
	float drift = TIME * 0.025;
	float wave = sin(ray.x * 8.0 + ray.z * 12.0 + drift);
	float belt = exp(-abs(ray.y - 0.13 + ray.x * 0.12 + wave * 0.025) * 31.0);
	float stream = 0.5 + 0.5 * sin(ray.x * 17.0 - ray.z * 9.0 - drift * 0.73);
	vec3 light = mix(vec3(0.018, 0.012, 0.052), vec3(0.013, 0.035, 0.071), stream)
		* belt * stream * sky_mask;

	vec3 vortex_center = normalize(vortex_direction);
	vec2 disk = on_disk(ray, vortex_center);
	float radius = length(disk);
	float arms = 0.5 + 0.5 * sin(atan(disk.y, disk.x) * 3.0
		+ log(max(radius, 0.004)) * 8.2 - TIME * 0.055);
	light += vec3(0.043, 0.025, 0.090) * exp(-radius * 17.0) * pow(arms, 4.0)
		* step(0.0, dot(ray, vortex_center)) * sky_mask;
	drift_light = light;
}

void fragment() {
	vec3 ray = normalize(world_position - CAMERA_POSITION_WORLD);
	vec3 planet_center = normalize(planet_direction);
	float planet_mask = dot(ray, planet_center) > 0.0 ? smoothstep(planet_radius * 0.999,
		planet_radius * 1.008, length(on_disk(ray, planet_center))) : 1.0;
	// Faint scattered sky color, deliberately below bloom. Using unlit additive
	// color here avoids lighting a fullscreen shell; arena runes use EMISSION.
	ALBEDO = drift_light * planet_mask * 3.0;
	ALPHA = 1.0;
}
