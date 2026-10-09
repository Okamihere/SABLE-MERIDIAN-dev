shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.27, 0.12, 0.43, 0.42);
uniform float wobble = 0.025;

void vertex() {
	VERTEX.y += sin(TIME * 8.0 + VERTEX.x * 13.0 + VERTEX.z * 17.0) * wobble;
}

void fragment() {
	ALBEDO = ink_color.rgb;
	ALPHA = ink_color.a;
}
