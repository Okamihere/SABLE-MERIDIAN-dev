shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.055, 0.15, 0.21, 1.0);
uniform vec4 surface_color : source_color = vec4(0.13, 0.32, 0.39, 1.0);
uniform vec4 glint_color : source_color = vec4(0.32, 0.58, 0.64, 1.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float wave_a = sin(world_xz.x * 0.12 + TIME * 0.38 + sin(world_xz.y * 0.045) * 0.7);
	float wave_b = sin(world_xz.y * 0.17 - TIME * 0.29 + world_xz.x * 0.035);
	float ripple = wave_a * 0.6 + wave_b * 0.4;
	float fine_ripple = sin(world_xz.x * 0.32 - world_xz.y * 0.21 + TIME * 0.6);
	float glint = pow(max(wave_a, 0.0), 24.0) * 0.09;
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep_color.rgb, surface_color.rgb, clamp(0.55 + ripple * 0.16 + fine_ripple * 0.025, 0.0, 1.0))
		+ glint_color.rgb * (glint + fresnel * 0.12);
}
