
shader_type spatial;
render_mode cull_disabled;

// Textura original das folhas (se existir)
uniform sampler2D leaf_texture : source_color, hint_default_white;
uniform vec4 leaf_tint : source_color = vec4(0.72, 0.88, 0.32, 1.0);

// VENTO
uniform float wind_strength : hint_range(0.0, 1.0) = 0.18;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.2;
uniform vec2 wind_direction = vec2(1.0, 0.35);

// Movimento por altura
uniform float base_height = 0.0;
uniform float top_height = 8.0;
uniform float upper_leaf_influence : hint_range(0.0, 2.0) = 1.0;

// Aparência pixel art
uniform float color_levels : hint_range(2.0, 16.0) = 5.0;
uniform float color_contrast : hint_range(0.5, 2.0) = 1.15;

// Variação entre regiões da copa
uniform float variation = 0.7;

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    float height_factor = smoothstep(
        base_height,
        max(base_height + 0.01, top_height),
        VERTEX.y
    );

    // Movimento contínuo, com pequenas diferenças espaciais
    float phase = dot(world_pos.xz, vec2(0.65, 0.48));

    float wave = sin(TIME * wind_speed + phase);
    float secondary_wave = sin(TIME * wind_speed * 1.7 + phase * 1.8);

    float sway = wave + secondary_wave * 0.25 * variation;

    float influence = height_factor * upper_leaf_influence;

    vec2 direction = normalize(wind_direction);

    VERTEX.xz += direction * sway * wind_strength * influence;

    // Pequeno movimento secundário
    VERTEX.xz += vec2(-direction.y, direction.x)
        * secondary_wave * wind_strength * 0.12 * influence;
}

void fragment() {
    vec4 tex = texture(leaf_texture, UV);

    vec3 color = tex.rgb * leaf_tint.rgb;

    color = (color - 0.5) * color_contrast + 0.5;
    color = clamp(color, 0.0, 1.0);

    float levels = max(color_levels, 2.0);
    color = floor(color * levels + 0.5) / levels;

    ALBEDO = color;

    // Recorte das áreas transparentes
    ALPHA = tex.a * leaf_tint.a;
    ALPHA_SCISSOR_THRESHOLD = 0.5;

    ROUGHNESS = 1.0;
}