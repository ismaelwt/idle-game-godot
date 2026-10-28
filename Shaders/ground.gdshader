shader_type spatial;

uniform sampler2D grass_texture : source_color;
uniform sampler2D dirt_texture : source_color;

uniform float path_width : hint_range(0.0, 1.0) = 0.35;
uniform float path_softness : hint_range(0.0, 0.5) = 0.08;

// Tamanho da grade de pixels
uniform float pixel_size : hint_range(1.0, 256.0) = 64.0;

void fragment() {

    vec2 uv = UV;

    // Centro do terreno
    float center = abs(uv.x - 0.5);

    // Faixa de terra
    float dirt_mask = 1.0 - smoothstep(
        path_width * 0.5,
        path_width * 0.5 + path_softness,
        center
    );

    // UV das texturas
    vec2 texture_uv = uv * 6.0;

    // PIXELIZAÇÃO DA TEXTURA
    texture_uv = floor(texture_uv * pixel_size) / pixel_size;

    // Texturas
    vec4 grass = texture(grass_texture, texture_uv);
    vec4 dirt = texture(dirt_texture, texture_uv);

    // Mistura grama + terra
    ALBEDO = mix(grass.rgb, dirt.rgb, dirt_mask);

    // Mantém a iluminação normal do material
    ROUGHNESS = 1.0;
}