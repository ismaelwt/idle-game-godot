shader_type spatial;

render_mode cull_disabled, unshaded;

uniform vec4 aura_color_top : source_color = vec4(0.8, 0.1, 1.0, 1.0);
uniform vec4 aura_color_bottom : source_color = vec4(0.1, 0.0, 0.4, 1.0);

void fragment() {

	float movement = fract(UV.y + TIME * 0.5);

	float energy = 1.0 - smoothstep(
		0.0,
		0.5,
		movement
	);

	// ==========================
	// FADE SUAVE
	// ==========================

	float fade_bottom = smoothstep(
		0.0,
		0.30,
		UV.y
	);

	float fade_top = 1.0 - smoothstep(
		0.70,
		1.0,
		UV.y
	);

	float fade = fade_bottom * fade_top;

	float final_alpha = energy * fade;


	// ==========================
	// DITHERING
	// ==========================

	vec2 pixel = floor(UV * 100.0);

	float noise = fract(
		sin(
			dot(
				pixel,
				vec2(12.9898, 78.233)
			)
		) * 43758.5453
	);

	if (noise > final_alpha) {
		discard;
	}


	// ==========================
	// GRADIENTE
	// ==========================

	vec3 gradient_color = mix(
		aura_color_bottom.rgb,
		aura_color_top.rgb,
		UV.y
	);

	ALBEDO = gradient_color;
	EMISSION = gradient_color * 2.0;
}