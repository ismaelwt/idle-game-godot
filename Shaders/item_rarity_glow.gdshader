shader_type canvas_item;

uniform vec4 rarity_color : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 3.0) = 1.35;
uniform float glow_radius : hint_range(1.0, 5.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.2;

void fragment() {
	vec4 item_color = texture(TEXTURE, UV) * COLOR;
	vec2 pixel = TEXTURE_PIXEL_SIZE * glow_radius;

	float surrounding_alpha = 0.0;
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + pixel).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - pixel).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);

	float outer_edge = max(surrounding_alpha - item_color.a, 0.0);
	float pulse = 0.78 + 0.22 * sin(TIME * pulse_speed);
	float glow_alpha = outer_edge * glow_strength * pulse * rarity_color.a;

	vec3 final_rgb = item_color.rgb + rarity_color.rgb * glow_alpha;
	float final_alpha = max(item_color.a, glow_alpha);

	COLOR = vec4(final_rgb, final_alpha);
}
