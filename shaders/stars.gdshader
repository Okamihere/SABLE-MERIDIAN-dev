shader_type spatial;
render_mode unshaded, cull_front;

uniform float cells = 80.0;
uniform float density = 0.965;
uniform float brightness = 1.3;
uniform float twinkle_speed = 1.8;

varying vec3 obj_pos;

float hash13(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

void vertex() {
    obj_pos = VERTEX;
}

void fragment() {
    vec3 dir = normalize(obj_pos);
    vec3 cell = floor(dir * cells);
    float h = hash13(cell);
    float star = 0.0;
    if (h > density) {
        vec3 rnd = vec3(
            hash13(cell + vec3(1.0, 7.0, 13.0)),
            hash13(cell + vec3(29.0, 3.0, 11.0)),
            hash13(cell + vec3(5.0, 23.0, 2.0))
        );
        vec3 cell_dir = normalize((cell + 0.5 + (rnd - 0.5) * 0.7) / cells);
        float d = distance(dir, cell_dir) * cells;
        star = smoothstep(0.28, 0.02, d);
        star *= 0.65 + 0.35 * sin(TIME * twinkle_speed + h * 628.0);
    }
    ALBEDO = vec3(0.0);
    EMISSION = vec3(0.85, 0.9, 1.0) * star * brightness;
}
