shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float focus_distance = 3.9;
uniform float blur_strength : hint_range(0.0, 1.0) = 0.86;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float distance_to_camera = -view.z / view.w;
	float blur = smoothstep(0.28, 1.45, abs(distance_to_camera - focus_distance)) * blur_strength;
	vec3 sharp = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	ALBEDO = sharp;
	if (blur > 0.001) {
		vec2 radius = vec2(7.0) / vec2(textureSize(screen_texture, 0));
		vec3 soft = vec3(0.0);
		for (int x = -2; x <= 2; x++) {
			for (int y = -2; y <= 2; y++) {
				float weight = (3.0 - abs(float(x))) * (3.0 - abs(float(y))) / 81.0;
				soft += textureLod(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * radius, 0.0).rgb * weight;
			}
		}
		ALBEDO = mix(sharp, soft, blur);
	}
}
