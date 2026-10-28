
shader_type spatial;

render_mode unshaded, cull_disabled;

uniform vec4 effect_color : source_color = vec4(0.1, 0.45, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.85, 0.98, 1.0, 1.0);

uniform float speed : hint_range(0.1, 10.0) = 3.0;
uniform float bolt_width : hint_range(0.01, 0.3) = 0.08;
uniform float glow : hint_range(0.0, 10.0) = 4.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float branch_strength : hint_range(0.0, 1.0) = 0.7;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float lightning_line(vec2 uv, float seed, float width) {
	float segment = floor(uv.y * 14.0);
	float local_y = fract(uv.y * 14.0);

	float x1 = (hash21(vec2(segment, seed)) - 0.5) * 1.2;
	float x2 = (hash21(vec2(segment + 1.0, seed)) - 0.5) * 1.2;
	
	float curve = smoothstep(0.0, 1.0, local_y);
	float bolt_x = mix(x1, x2, curve);
	float distance_to_line = abs(uv.x - bolt_x);

	return 1.0 - smoothstep(width * 0.5, width, distance_to_line);
}

void fragment() {
	vec2 uv = UV;
	uv.x = (uv.x - 0.5) * 2.0;
	uv.y = 1.0 - uv.y;

	float time_id = floor(TIME * speed);
	float pulse = 0.65 + 0.35 * sin(TIME * speed * 8.0);

	// Raio principal
	float main_bolt = lightning_line(
		uv,
		time_id + 1.0,
		bolt_width
	);

	// Ramificações laterais
	vec2 left_uv = uv;
	left_uv.x += 0.28;

	float left_bolt = lightning_line(
		left_uv,
		time_id + 7.0,
		bolt_width * 0.55
	);

	left_bolt *= step(0.25, uv.y) * (1.0 - step(0.75, uv.y));

	vec2 right_uv = uv;
	right_uv.x -= 0.28;

	float right_bolt = lightning_line(
		right_uv,
		time_id + 13.0,
		bolt_width * 0.55
	);

	right_bolt *= step(0.35, uv.y) * (1.0 - step(0.85, uv.y));

	float core = max(
		main_bolt,
		max(left_bolt, right_bolt) * branch_strength
	);

	// Halo ao redor do núcleo
	float halo = max(
		lightning_line(uv, time_id + 1.0, bolt_width * 3.5),
		max(
			lightning_line(left_uv, time_id + 7.0, bolt_width * 2.5),
			lightning_line(right_uv, time_id + 13.0, bolt_width * 2.5)
		) * branch_strength
	);

	vec3 color = effect_color.rgb * halo * glow;
	color = mix(color, core_color.rgb, core);

	float alpha = clamp(max(halo * 0.45, core), 0.0, 1.0);
	alpha *= pulse * opacity;

	ALBEDO = color;
	EMISSION = color * glow;
	ALPHA_SCISSOR_THRESHOLD = 0.05;
	ALPHA = alpha;
}