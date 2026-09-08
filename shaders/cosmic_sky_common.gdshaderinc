// Shared original nebula, planet and vortex equations for the sky and its one-time bake.
uniform vec3 planet_direction = vec3(-0.29, 0.38, -0.92);
uniform float planet_radius = 0.27;
uniform vec3 vortex_direction = vec3(0.57, 0.26, -0.78);

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x),
		mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
		mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float sum = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += noise3(p) * weight;
		p = p * 2.07 + vec3(13.1, 5.4, 7.6);
		weight *= 0.51;
	}
	return sum;
}
float stars(vec3 ray, float density) {
	vec3 cell = ray * density;
	vec3 id = floor(cell);
	vec3 local = fract(cell) - vec3(0.5);
	float chance = hash31(id);
	float star = 1.0 - smoothstep(0.045, 0.19, length(local));
	return star * step(0.987, chance) * (0.25 + 0.75 * hash31(id + 7.1));
}
vec2 on_disk(vec3 ray, vec3 center) {
	vec3 right = normalize(cross(center, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, center);
	return vec2(dot(ray, right), dot(ray, up));
}

vec3 cosmic_background(vec3 ray) {
	vec3 space = vec3(0.008, 0.006, 0.030);
	float horizon = exp(-abs(ray.y + 0.035) * 6.0);
	space += vec3(0.045, 0.021, 0.088) * horizon;
	vec3 p = ray * 3.6 + vec3(7.2, 0.5, 3.1);
	float cloud = fbm(p);
	float warp = fbm(p * 1.7 + 12.6);
	float filaments = fbm(p * 3.4 + cloud * 3.6);
	float belt = exp(-pow((ray.y - 0.05 + ray.x * 0.28) * 2.4, 2.0));
	float nebula = smoothstep(0.33, 0.77, cloud + 0.16 * warp) * belt;
	vec3 nebula_color = mix(vec3(0.075, 0.022, 0.22), vec3(0.28, 0.08, 0.44), filaments);
	space += nebula_color * nebula;
	float thread = pow(clamp(1.0 - abs(filaments - 0.51) * 15.0, 0.0, 1.0), 3.0);
	space += vec3(0.065, 0.024, 0.14) * thread * nebula;
	space += vec3(0.011, 0.037, 0.075) * smoothstep(0.50, 0.73, warp) * belt;

	// The pale vortex is on the opposite side from the blue planet.
	vec3 vortex_center = normalize(vortex_direction);
	vec2 v = on_disk(ray, vortex_center);
	float vr = length(v);
	float face_vortex = step(0.0, dot(ray, vortex_center));
	float va = atan(v.y, v.x);
	float arms = 0.5 + 0.5 * sin(va * 3.0 + log(max(vr, 0.004)) * 8.2);
	float ve = exp(-vr * 17.0) * face_vortex;
	float vortex_detail = fbm(vec3(v * 72.0, 31.0));
	space += mix(vec3(0.18, 0.03, 0.46), vec3(0.25, 0.43, 0.80), vortex_detail)
		* ve * (0.5 + 1.4 * pow(arms, 3.0));
	space += vec3(0.78, 0.65, 1.0) * exp(-vr * vr * 2700.0) * face_vortex * 0.9;

	// Textured sphere, with a dark terminator and a thin atmospheric limb.
	vec3 planet_center = normalize(planet_direction);
	vec2 disk = on_disk(ray, planet_center) / planet_radius;
	float radius = length(disk);
	float face_planet = step(0.0, dot(ray, planet_center));
	float halo = exp(-abs(radius - 1.0) * 17.0) * face_planet;
	space += vec3(0.09, 0.19, 0.46) * halo * 0.30;
	if (radius < 1.0 && face_planet > 0.0) {
		vec3 normal = vec3(disk, sqrt(max(0.0, 1.0 - radius * radius)));
		float light = pow(max(dot(normal, normalize(vec3(0.90, 0.18, 0.33))), 0.0), 0.72);
		float terrain = fbm(normal * 8.0 + vec3(41.0, 13.0, 2.0));
		float cloud_cover = fbm(normal * 15.0 + vec3(5.0, terrain * 3.0, 61.0));
		vec3 planet = mix(vec3(0.014, 0.020, 0.066), vec3(0.024, 0.10, 0.20), terrain);
		planet = mix(planet, vec3(0.12, 0.26, 0.41), smoothstep(0.46, 0.70, cloud_cover));
		planet *= 0.23 + light * 2.0;
		float limb = pow(1.0 - normal.z, 5.0);
		planet += vec3(0.13, 0.33, 0.63) * limb * (0.13 + 0.87 * light);
		planet += vec3(0.07, 0.12, 0.26) * pow(1.0 - normal.z, 21.0);
		space = mix(space, planet, smoothstep(1.0, 0.997, radius));
	}
	// Layered violet dust catches light beneath the islands and around the far crags.
	float mist_detail = fbm(ray * vec3(8.0, 14.0, 8.0) + vec3(16.7, 2.1, 40.0));
	float mist_band = exp(-pow((ray.y + 0.18) * 3.5, 2.0));
	space += vec3(0.067, 0.023, 0.123) * mist_band * (0.45 + mist_detail * 0.65);
	float below = smoothstep(-0.20, -0.90, ray.y);
	space = mix(space, vec3(0.028, 0.012, 0.060), below * 0.85);
	return space;
}

