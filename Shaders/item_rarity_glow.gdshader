shader_type canvas_item;

uniform vec4 rarity_color : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform float border_thickness : hint_range(0.01, 0.2) = 0.07;
uniform float segment_length : hint_range(0.05, 0.5) = 0.24;
uniform float animation_speed : hint_range(0.05, 1.0) = 0.22;
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float border = 1.0 - smoothstep(border_thickness, border_thickness + 0.018, edge_distance);

	float perimeter_position;
	if (UV.y <= UV.x && UV.y <= 1.0 - UV.x) {
		perimeter_position = UV.x;
	} else if (UV.x >= UV.y && UV.x >= 1.0 - UV.y) {
		perimeter_position = 1.0 + UV.y;
	} else if (UV.y >= UV.x && UV.y >= 1.0 - UV.x) {
		perimeter_position = 2.0 + (1.0 - UV.x);
	} else {
		perimeter_position = 3.0 + (1.0 - UV.y);
	}
	perimeter_position *= 0.25;

	float head_position = fract(TIME * animation_speed);
	float distance_to_segment = abs(fract(perimeter_position - head_position + 0.5) - 0.5);
	float moving_glow = 1.0 - smoothstep(segment_length * 0.35, segment_length, distance_to_segment);
	float pulse = 0.78 + 0.22 * sin(TIME * 3.0);

	float alpha = border * (0.22 + moving_glow * 0.78) * pulse * glow_strength;
	vec3 color = rarity_color.rgb * (0.72 + moving_glow * 0.65);
	COLOR = vec4(color, alpha * rarity_color.a);
}
