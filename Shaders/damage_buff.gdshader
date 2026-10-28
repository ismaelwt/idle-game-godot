shader_type spatial;

render_mode cull_disabled;

uniform vec4 aura_color_top : source_color = vec4(0.8, 0.1, 1.0, 1.0);
uniform vec4 aura_color_bottom : source_color = vec4(0.1, 0.0, 0.4, 1.0);

void fragment() {

	float movement = fract(UV.y + TIME * 0.5);

	// Faixa de energia
	float alpha = 1.0 - smoothstep(
		0.0,
		0.5,
		movement
	);

	// Pixelização
	vec2 pixel_uv = floor(UV * 40.0) / 80.0;

	float dissolve = fract(
		sin(
			dot(
				pixel_uv,
				vec2(12.9898, 78.233)
			)
		) * 43758.5453
	);

	// Dissolve pixelado
	float dissolve_mask = step(
		0.35,
		dissolve
	);

	alpha *= dissolve_mask;

	// Gradiente entre duas cores
	vec3 gradient_color = mix(
		aura_color_bottom.rgb,
		aura_color_top.rgb,
		UV.y
	);

	ALBEDO = gradient_color;

	EMISSION = gradient_color * 2.0;

	ALPHA_SCISSOR_THRESHOLD = 0.1;

	ALPHA = alpha * 0.35;
}