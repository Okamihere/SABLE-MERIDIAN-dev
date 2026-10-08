shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D screen_texture : filter_linear;
uniform vec4 screen_tint : source_color = vec4(1.0);
uniform float scanline_strength = 0.095;
uniform float noise_strength = 0.012;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 curved_uv = UV + p * dot(p, p) * 0.012;
	vec4 screen = texture(screen_texture, curved_uv);
	float edge = smoothstep(0.0, 0.065, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	float vignette = 1.0 - 0.17 * dot(p, p);
	float scanlines = 1.0 - scanline_strength * (0.5 + 0.5 * sin(UV.y * 650.0 * 3.141593));
	vec2 pixel = floor(UV * vec2(700.0, 450.0)) + floor(TIME * 18.0);
	float noise = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	float worn_line = fract(sin(dot(floor(UV * vec2(190.0, 95.0)), vec2(39.346, 11.135))) * 47453.21);
	float wear = smoothstep(0.985, 1.0, worn_line) * 0.012;
	float flicker = 0.99 + 0.012 * sin(TIME * 7.0) + 0.006 * sin(TIME * 19.0);
	vec3 color = screen.rgb * vignette * scanlines * edge * flicker + noise * noise_strength + vec3(0.3, 0.7, 0.85) * wear;
	ALBEDO = max(color, vec3(0.0)) * 1.1 * screen_tint.rgb;
	EMISSION = max(color - vec3(0.18), vec3(0.0)) * 0.48 * screen_tint.rgb;
}
