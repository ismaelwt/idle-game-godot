
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D noise_sampler : filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient_sampler : filter_linear, source_color;

uniform float emission_strength = 2.0;

// Dithering
uniform float dither_scale = 2.0;
uniform float dither_strength = 0.15;

float fresnel(float amount, vec3 normal, vec3 view) {
    return pow(
        1.0 - clamp(
            dot(normalize(normal), normalize(view)),
            0.0,
            0.5
        ),
        amount
    );
}

void fragment() {
    float noise = texture(
        noise_sampler,
        UV - vec2(0.0, TIME)
    ).x;

    vec3 gradient = texture(
        gradient_sampler,
        vec2(UV.y, 0.0)
    ).rgb;

    // Padrão de dithering em coordenadas da tela
    vec2 pixel = floor(FRAGCOORD.xy / dither_scale);

    float dither = fract(
        52.9829189 * fract(
            dot(pixel, vec2(0.06711056, 0.00583715))
        )
    );

    // Mantém o recorte original e adiciona variação pontilhada
    float dissolve = noise - UV.y + 0.1;
    float threshold = (dither - 0.5) * dither_strength;

    ALPHA = step(-threshold, dissolve);
    ALPHA_SCISSOR_THRESHOLD = 0.5;

    ALBEDO = gradient;

    EMISSION = (
        gradient + step(0.25, fresnel(2.5, NORMAL, VIEW))
    ) * emission_strength;
}
