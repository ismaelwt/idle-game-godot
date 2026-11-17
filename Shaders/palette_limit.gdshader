
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D palette_texture : filter_nearest, repeat_disable;

uniform int palette_size : hint_range(2, 64, 1) = 64;
uniform float palette_strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 original = texture(screen_texture, SCREEN_UV);

    if (original.a <= 0.001) {
        COLOR = original;
    } else {
        vec3 best_color = original.rgb;
        float best_distance = 999999.0;

        for (int i = 0; i < palette_size; i++) {
            float u = (float(i) + 0.5) / float(palette_size);

            vec3 palette_color = texture(
                palette_texture,
                vec2(u, 0.5)
            ).rgb;

            vec3 difference = original.rgb - palette_color;
            float color_distance = dot(difference, difference);

            if (color_distance < best_distance) {
                best_distance = color_distance;
                best_color = palette_color;
            }
        }

        COLOR = vec4(
            mix(original.rgb, best_color, palette_strength),
            original.a
        );
    }
}
