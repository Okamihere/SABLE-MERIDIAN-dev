shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque, diffuse_burley, specular_disabled;

// Agua estilizada PS2/low-poly: textura -> distorcao -> fresnel -> caustics animadas.
// Sem SCREEN_TEXTURE/DEPTH_TEXTURE: seguro no GL Compatibility.

uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform vec4 deep_color : source_color = vec4(0.015, 0.09, 0.16, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.03, 0.35, 0.45, 1.0);
uniform vec4 fresnel_color : source_color = vec4(0.35, 0.85, 0.95, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.45, 0.95, 1.0, 1.0);

uniform float flow_speed = 0.06;
uniform float wobble_speed = 0.35;
uniform vec2 flow_direction = vec2(1.0, 0.35);
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.08;
uniform float texture_scale = 3.0;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;
uniform float fresnel_intensity : hint_range(0.0, 2.0) = 0.9;
uniform float caustic_scale = 5.0;
uniform float caustic_speed = 0.25;
uniform float caustic_sharpness : hint_range(1.0, 12.0) = 5.0;
uniform float caustic_intensity : hint_range(0.0, 2.0) = 0.7;
uniform float alpha : hint_range(0.0, 1.0) = 0.92;
uniform float band_steps : hint_range(2.0, 16.0) = 6.0;
uniform bool use_world_coordinates = false;

varying vec2 water_uv;

void vertex() {
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 wave_xz = use_world_coordinates ? world_xz : VERTEX.xz;
	water_uv = use_world_coordinates ? world_xz * 0.5 : UV;
	// Ondulacao lenta e irregular no vertice (relevo baixo, estilo low-poly).
	float t = TIME * wobble_speed;
	float bob = sin(wave_xz.x * 0.8 + t * 1.7) * 0.5
		+ sin(wave_xz.y * 1.1 - t * 1.2) * 0.3
		+ sin((wave_xz.x + wave_xz.y) * 0.45 + t * 0.6) * 0.2;
	VERTEX.y += bob * 0.035;
}

void fragment() {
	vec2 flow = normalize(flow_direction) * flow_speed * TIME;
	vec2 wobble_uv = water_uv * texture_scale + flow;

	// 1) TEXTURA: duas amostras low-res em scroll cruzado para movimento irregular.
	float grain_a = texture(noise_tex, wobble_uv).r;
	float grain_b = texture(noise_tex, wobble_uv * 1.7 - flow * 1.6 + vec2(0.37, 0.61)).g;
	float grain = grain_a * 0.6 + grain_b * 0.4;

	// 2) DISTORCAO: o grao desloca os UVs das etapas seguintes (sutil).
	vec2 distorted_uv = water_uv + (vec2(grain_a, grain_b) - 0.5) * distortion_strength * 2.0;

	// 3) FRESNEL: destaca as bordas vistas de raspao.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, fresnel_power) * fresnel_intensity;

	// 4) CAUSTICS ANIMADAS: duas ondas de ruido em contra-fluxo, afuniladas e em faixas.
	float caustic_uv_scale = caustic_scale / max(texture_scale, 0.001);
	vec2 drift = normalize(flow_direction) * caustic_speed * TIME;
	float c1 = texture(noise_tex, distorted_uv * caustic_uv_scale + drift * 0.4).b;
	float c2 = texture(noise_tex, distorted_uv * caustic_uv_scale * 1.35 - drift * 0.55 + vec2(0.53, 0.17)).r;
	float caustic = pow(clamp(c1 * c2 * 2.2, 0.0, 1.0), caustic_sharpness);
	caustic = floor(caustic * band_steps) / band_steps; // faixas duras, sem realismo.

	vec3 base = mix(deep_color.rgb, shallow_color.rgb, grain);
	vec3 col = base + caustic_color.rgb * (caustic * caustic_intensity);
	col = mix(col, fresnel_color.rgb, clamp(fresnel, 0.0, 1.0));

	ALBEDO = col;
	EMISSION = col * 0.35;
	ALPHA = alpha;
}
