shader_type spatial;

render_mode cull_disabled;

// ==========================================
// VELOCIDADE E TAMANHO
// ==========================================

uniform float speed : hint_range(0.1, 5.0) = 0.5;

uniform float bar_size : hint_range(0.05, 1.0) = 0.5;


// ==========================================
// CORES
// ==========================================

uniform vec4 aura_color_top : source_color =
	vec4(0.8, 0.1, 1.0, 1.0);

uniform vec4 aura_color_bottom : source_color =
	vec4(0.1, 0.0, 0.4, 1.0);


// ==========================================
// TRAÇOS
// ==========================================

uniform float spiral_count : hint_range(1.0, 15.0) = 5.0;

uniform float trail_thickness : hint_range(0.01, 0.3) = 0.12;


// ==========================================
// BRILHO
// ==========================================

uniform float glow : hint_range(0.0, 10.0) = 2.0;


void fragment() {

	// ==========================================
	// MOVIMENTO DA FAIXA
	// ==========================================

	float movement = fract(
		UV.y + TIME * speed
	);


	// ==========================================
	// FAIXA DE ENERGIA
	// ==========================================

	float alpha = 1.0 - smoothstep(
		0.0,
		bar_size,
		movement
	);


	// ==========================================
	// VÁRIOS TRAÇOS SUBINDO
	// ==========================================

	float spiral = (
		UV.x * spiral_count
		+ UV.y * 2.0
		+ TIME * speed
	);

	float line = abs(
		fract(spiral) - 0.5
	);

	float trails = 1.0 - smoothstep(
		0.02,
		trail_thickness,
		line
	);


	// ==========================================
	// FADE DOS TRAÇOS
	// ==========================================

	float fade_bottom = smoothstep(
		0.0,
		0.15,
		UV.y
	);

	float fade_top = 1.0 - smoothstep(
		0.70,
		1.0,
		UV.y
	);

	trails *= fade_bottom * fade_top;


	// Adiciona os traços
	alpha = max(
		alpha,
		trails
	);


	// ==========================================
	// EXPLOSÃO NO TOPO
	// ==========================================

	vec2 center = vec2(
		0.5,
		1.0
	);

	vec2 offset = UV - center;

	float distance_from_center = length(
		offset
	);


	// Movimento da explosão
	float explosion_progress = fract(
		TIME * speed * 0.8
	);

	float explosion_radius =
		explosion_progress * 0.8;


	// Anel da explosão
	float explosion_ring = abs(
		distance_from_center
		- explosion_radius
	);

	float explosion = 1.0 - smoothstep(
		0.01,
		0.08,
		explosion_ring
	);


	// Explosão somente no topo
	float explosion_mask = smoothstep(
		0.65,
		1.0,
		UV.y
	);

	explosion *= explosion_mask;


	// Adiciona explosão
	alpha = max(
		alpha,
		explosion
	);


	// ==========================================
	// GRADIENTE DE COR
	// ==========================================

	vec3 gradient_color = mix(
		aura_color_bottom.rgb,
		aura_color_top.rgb,
		UV.y
	);


	// ==========================================
	// MATERIAL
	// ==========================================

	ALBEDO = gradient_color;

	EMISSION =
		gradient_color
		* glow;


	// ==========================================
	// TRANSPARÊNCIA
	// ==========================================

	ALPHA_SCISSOR_THRESHOLD = 0.1;

	ALPHA = alpha * 0.35;
}