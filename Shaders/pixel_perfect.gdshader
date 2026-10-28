shader_type canvas_item;

uniform vec2 offset_uv = vec2(0.0);

void fragment() {
	vec2 uv = UV - offset_uv;

	COLOR = texture(TEXTURE, uv);
}