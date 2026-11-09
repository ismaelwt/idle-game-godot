shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.08, 1.0);
uniform float border_thickness : hint_range(0.005, 0.08) = 0.065;
uniform float segment_length : hint_range(0.05, 0.5) = 0.22;
uniform float animation_speed : hint_range(0.05, 1.0) = 0.24;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;

	float edge_distance = min(
		min(UV.x, 1.0 - UV.x),
		min(UV.y, 1.0 - UV.y)
	);
	float border = 1.0 - smoothstep(
		border_thickness,
		border_thickness + 0.012,
		edge_distance
	);

	// Coordenada contínua ao redor do quadrado, no sentido horário.
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
	float distance_to_segment = abs(
		fract(perimeter_position - head_position + 0.5) - 0.5
	);
	float moving_glow = 1.0 - smoothstep(
		segment_length * 0.35,
		segment_length,
		distance_to_segment
	);

	float glow = border * (0.22 + moving_glow * 0.95);
	vec3 result_color = mix(base_color.rgb, glow_color.rgb, glow);
	result_color += glow_color.rgb * border * moving_glow * 0.28;

	COLOR = vec4(
		result_color,
		max(base_color.a, border * glow_color.a * (0.35 + moving_glow * 0.65))
	);
}
