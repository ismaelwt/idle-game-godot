
shader_type spatial;

render_mode cull_disabled;

// ==========================================
// MOVIMENTO DOS SINAIS +
// ==========================================

uniform float speed : hint_range(0.1, 5.0) = 0.8;
uniform float symbol_count : hint_range(2.0, 20.0) = 9.0;
uniform float symbol_size : hint_range(0.01, 0.15) = 0.045;

uniform float horizontal_speed : hint_range(0.0, 5.0) = 1.5;
uniform float horizontal_amount : hint_range(0.0, 2.0) = 0.5;
uniform float wave_frequency : hint_range(0.1, 5.0) = 0.8;

// ==========================================
// CORES DOS SINAIS +
// ==========================================

uniform vec4 healing_color_top : source_color =
	vec4(0.75, 1.0, 0.85, 1.0);

uniform vec4 healing_color_bottom : source_color =
	vec4(0.1, 1.0, 0.3, 1.0);

// ==========================================
// BRILHO E OPACIDADE DOS SINAIS
// ==========================================

uniform float glow : hint_range(0.0, 10.0) = 3.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;

// ==========================================
// PIXELIZAÇÃO
// ==========================================

uniform float pixel_scale : hint_range(10.0, 100.0) = 40.0;
uniform float dissolve_threshold : hint_range(0.0, 1.0) = 0.35;

// ==========================================
// FAIXA ROXA LISA
// ==========================================

uniform float bar_speed : hint_range(0.1, 5.0) = 0.5;
uniform float bar_size : hint_range(0.05, 1.0) = 0.5;

uniform vec4 aura_color_top : source_color =
	vec4(0.8, 0.1, 1.0, 1.0);

uniform vec4 aura_color_bottom : source_color =
	vec4(0.1, 0.0, 0.4, 1.0);

uniform float aura_glow : hint_range(0.0, 10.0) = 2.0;
uniform float aura_opacity : hint_range(0.0, 1.0) = 0.35;

// ==========================================
// FORMATO DO SINAL +
// ==========================================

float plus_symbol(vec2 uv, float size) {
	float thickness = size * 0.28;

	float horizontal =
		step(abs(uv.y), thickness) *
		step(abs(uv.x), size);

	float vertical =
		step(abs(uv.x), thickness) *
		step(abs(uv.y), size);

	return max(horizontal, vertical);
}

// ==========================================
// SHADER
// ==========================================

void fragment() {

	// ==========================================
	// SINAIS + ORIGINAIS
	// ==========================================

	vec2 grid_uv = vec2(
		UV.x * 4.0,
		UV.y * symbol_count
	);

	// Subida vertical
	grid_uv.y += TIME * speed;

	// Movimento lateral ondulado
	grid_uv.x += sin(
		grid_uv.y * wave_frequency
		- TIME * horizontal_speed
	) * horizontal_amount;

	// Célula atual
	vec2 cell_id = floor(grid_uv);
	vec2 cell = fract(grid_uv) - 0.5;

	// Variação horizontal por símbolo
	float random_x = fract(
		sin(cell_id.y * 127.1) * 43758.5453
	);

	cell.x += (random_x - 0.5) * 0.45;

	// Tamanhos variados
	float random_size = mix(
		0.65,
		1.35,
		fract(
			sin(cell_id.y * 78.233) * 43758.5453
		)
	);

	float plus = plus_symbol(
		cell,
		symbol_size * random_size
	);

	// Ciclo de cada símbolo
	float life = fract(grid_uv.y);

	// Desaparecimento gradual
	float fade = 1.0 - smoothstep(
		0.55,
		1.0,
		life
	);

	// Pixelização
	vec2 pixel_uv = floor(UV * pixel_scale)
		/ (pixel_scale * 2.0);

	float dissolve = fract(
		sin(
			dot(
				pixel_uv,
				vec2(12.9898, 78.233)
			)
		) * 43758.5453
	);

	float dissolve_mask = step(
		dissolve_threshold,
		dissolve
	);

	float plus_alpha =
		plus * fade * dissolve_mask * opacity;

	// Gradiente verde
	vec3 plus_color = mix(
		healing_color_bottom.rgb,
		healing_color_top.rgb,
		UV.y
	);

	// ==========================================
	// FAIXA ROXA LISA EM MOVIMENTO
	// ==========================================

	float movement = fract(
		UV.y + TIME * bar_speed
	);

	float bar_alpha = 1.0 - smoothstep(
		0.0,
		bar_size,
		movement
	);

	// Gradiente roxo
	vec3 aura_color = mix(
		aura_color_bottom.rgb,
		aura_color_top.rgb,
		UV.y
	);

	// ==========================================
	// COMBINAÇÃO DOS EFEITOS
	// ==========================================

	float aura_alpha = bar_alpha * aura_opacity;

	float final_alpha = max(
		plus_alpha,
		aura_alpha
	);

	// Mantém os sinais verdes visíveis sobre a faixa
	vec3 final_color = mix(
		aura_color,
		plus_color,
		plus_alpha
	);

	// ==========================================
	// MATERIAL E BRILHO
	// ==========================================

	ALBEDO = final_color;

	EMISSION =
		plus_color * glow * plus_alpha
		+ aura_color * aura_glow * aura_alpha;

	// ==========================================
	// TRANSPARÊNCIA
	// ==========================================

	ALPHA_SCISSOR_THRESHOLD = 0.1;
	ALPHA = final_alpha;
}
