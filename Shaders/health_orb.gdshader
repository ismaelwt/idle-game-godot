
shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.75;
uniform float wave_speed = 0.7;
uniform float wave_strength = 0.025;
uniform float pixel_strength : hint_range(0.0, 1.0) = 0.18;

// Seletor de cores no Inspector.
uniform vec4 dark_color : source_color = vec4(0.22, 0.005, 0.015, 1.0);
uniform vec4 base_color : source_color = vec4(0.8, 0.025, 0.045, 1.0);
uniform vec4 bright_color : source_color = vec4(1.0, 0.22, 0.12, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.45, 0.35, 1.0);

void fragment() {
    float pixel_size = mix(1.0 / 512.0, 1.0 / 80.0, pixel_strength);
    vec2 pixel_uv = floor(UV / pixel_size) * pixel_size;

    vec2 p = UV * 2.0 - 1.0;
    float radius = length(p);
    float orb_mask = 1.0 - smoothstep(0.96, 1.0, radius);

    float wave = sin(pixel_uv.x * 12.0 + TIME * wave_speed)
        * wave_strength;

    float liquid_level = 1.0 - fill_amount;
    float surface = liquid_level + wave;

    float liquid_mask = smoothstep(
        surface - 0.008,
        surface + 0.008,
        pixel_uv.y
    );

    // Gradiente configurável.
    float gradient = pixel_uv.y;
    vec3 liquid_color = mix(dark_color.rgb, base_color.rgb, gradient);

    liquid_color = mix(
        liquid_color,
        bright_color.rgb,
        smoothstep(0.65, 1.0, gradient) * 0.65
    );

    // Reflexo principal.
    float highlight = 1.0 - smoothstep(
        0.0,
        0.48,
        length((UV - vec2(0.28, 0.18)) * vec2(1.0, 1.4))
    );

    float specular = 1.0 - smoothstep(
        0.0,
        0.075,
        length(UV - vec2(0.30, 0.16))
    );

    liquid_color += highlight_color.rgb * highlight * 0.30;
    liquid_color += vec3(1.0, 0.85, 0.75) * specular;

    // Volume nas bordas.
    float edge_shadow = smoothstep(0.55, 1.0, radius);
    liquid_color *= 1.0 - edge_shadow * 0.45;

    float alpha = orb_mask * liquid_mask;
    COLOR = vec4(liquid_color, alpha);
}
