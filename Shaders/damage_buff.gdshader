shader_type spatial;
render_mode cull_disabled;

uniform vec4 aura_color_top : source_color = vec4(0.8, 0.1, 1.0, 1.0);
uniform vec4 aura_color_bottom : source_color = vec4(0.1, 0.0, 0.4, 1.0);

// Movimento
uniform float speed = 0.5;
uniform float spiral_strength = 8.0;
uniform float spiral_speed = 2.0;

// Controle do gradiente
uniform float color_transition : hint_range(0.0, 1.0) = 0.5;
uniform float color_blend_width : hint_range(0.001, 1.0) = 0.2;

void fragment() {

	// Coordenadas da espiral
	vec2 centered_uv = UV - vec2(0.5);

	float angle = atan(centered_uv.x, centered_uv.y);

	// Rotação progressiva
	float spiral = angle * spiral_strength
		+ UV.y * 6.28318
		- TIME * spiral_speed;

	// Energia subindo em espiral
	float movement = fract(
		UV.y * 2.0
		- TIME * speed
		+ sin(spiral) * 0.08
	);

	float alpha = 1.0 - smoothstep(
		0.0,
		0.5,
		movement
	);

	// Transição entre as cores
	float color_mix = smoothstep(
		color_transition - color_blend_width * 0.5,
		color_transition + color_blend_width * 0.5,
		UV.y
	);

	vec3 gradient_color = mix(
		aura_color_bottom.rgb,
		aura_color_top.rgb,
		color_mix
	);

	ALBEDO = gradient_color;
	EMISSION = gradient_color * 2.0;

	ALPHA_SCISSOR_THRESHOLD = 0.1;
	ALPHA = alpha * 0.35;
}