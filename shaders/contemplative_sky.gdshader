shader_type sky;

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_speed : hint_range(0.0, 0.05) = 0.006;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 cell = floor(p);
	vec3 local_pos = fract(p);
	vec3 blend = local_pos * local_pos * (3.0 - 2.0 * local_pos);
	float a = mix(hash3(cell), hash3(cell + vec3(1.0, 0.0, 0.0)), blend.x);
	float b = mix(hash3(cell + vec3(0.0, 1.0, 0.0)), hash3(cell + vec3(1.0, 1.0, 0.0)), blend.x);
	float c = mix(hash3(cell + vec3(0.0, 0.0, 1.0)), hash3(cell + vec3(1.0, 0.0, 1.0)), blend.x);
	float d = mix(hash3(cell + vec3(0.0, 1.0, 1.0)), hash3(cell + vec3(1.0, 1.0, 1.0)), blend.x);
	return mix(mix(a, b, blend.y), mix(c, d, blend.y), blend.z);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float horizon = pow(1.0 - clamp(direction.y, 0.0, 1.0), 2.0);
	vec3 color = mix(vec3(0.014, 0.011, 0.038), vec3(0.095, 0.048, 0.105), horizon);
	color += vec3(0.09, 0.035, 0.055) * exp(-abs(direction.y) * 11.0);

	// A reflexão recebe só o gradiente; as nuvens se movem no fundo visível.
	if (!AT_CUBEMAP_PASS) {
		vec3 sample_pos = direction * vec3(3.1, 4.2, 3.1);
		sample_pos.xz += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.38);
		float broad = noise3(sample_pos * 0.57);
		float body = noise3(sample_pos + (broad - 0.5) * 0.65) * 0.55;
		body += noise3(sample_pos * 2.15) * 0.29;
		body += noise3(sample_pos * 4.35) * 0.16;
		float cloud_band = smoothstep(-0.12, 0.06, direction.y);
		cloud_band *= 1.0 - smoothstep(0.72, 0.97, direction.y);
		float cloud = smoothstep(0.63 - cloud_coverage * 0.25, 0.72 - cloud_coverage * 0.17, body);
		cloud *= cloud_band;
		vec3 shadow = vec3(0.105, 0.105, 0.18);
		vec3 highlight = vec3(0.42, 0.32, 0.43);
		vec3 cloud_color = mix(shadow, highlight, smoothstep(0.43, 0.72, body));
		color = mix(color, cloud_color, cloud * 0.94);

		vec3 moon_direction = normalize(vec3(-0.48, 0.42, -0.77));
		float moon_alignment = max(dot(direction, moon_direction), 0.0);
		float halo = pow(moon_alignment, 72.0);
		float moon = smoothstep(0.9987, 0.9994, moon_alignment);
		color += vec3(0.20, 0.15, 0.20) * halo;
		color = mix(color, vec3(0.90, 0.77, 0.67), moon * (1.0 - cloud * 0.55));
	}

	COLOR = color;
}
