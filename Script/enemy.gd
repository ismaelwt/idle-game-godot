
extends Node3D

@export_category("Movimento")
@export var speed: float = 2.0
@export var radius: float = 5.0

@export_category("Alvo")
@export var target_height: float = 1.5

@export_category("Vida")
@export var max_health: float = 15.0

@export_category("Level Scaling")
@export var enemy_level: int = 1
@export var health_per_level: float = 0.25
@export var damage_per_level: float = 0.12
@export var xp_per_level: float = 0.20
@export var gold_per_level: float = 0.10

var base_max_health: float
var base_attack_damage: float
var base_xp_reward: int
var base_gold_reward: int

@export_category("Recompensa")
@export var xp_reward: int = 25
@export var gold_reward: int = 10

@export_category("Dano Visual")
@export var damage_font_size: int = 128
@export var damage_outline_size: int = 6
@export var damage_height: float = 0.0
@export var damage_end_height: float = 0.2
@export var damage_duration: float = 1.0
@export var damage_rise_speed: float = 3.0
@export var damage_color: Color = Color(1, 0.2, 0.2, 1)
@export var damage_outline_color: Color = Color.BLACK

@export_category("Level Label")
@export var level_label_font_size: int = 64
@export var level_label_height: float = -0.3
@export var level_label_color: Color = Color.WHITE
@export var level_label_outline_size: int = 6
@export var level_label_outline_color: Color = Color.BLACK

var level_label: Label3D

@export_category("Ataque")
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0
@export var attack_damage: float = 3.0
@export var attack_hit_delay: float = 1.0

const DAMAGE_FONT: Font = preload("res://Fonts/Pix32.ttf")

@onready var animation_player = $AnimationPlayer
@onready var health_bar: ProgressBar = $SubViewport/ProgressBar
@onready var health_bar_display: Sprite3D = $HealthBarDisplay

var player: Node3D
var combat_target: Node3D = null

var health: float
var center_position: Vector3
var angle: float = 0.0

var attacking: bool = false
var dying: bool = false
var in_combat: bool = false
var attack_timer: float = 0.0


func _ready() -> void:
	health_bar_display.visible = true
	animation_player.animation_finished.connect(_on_animation_finished)

	animation_player.play("enemy/walk")

	center_position = global_position

	base_max_health = max_health
	base_attack_damage = attack_damage
	base_xp_reward = xp_reward
	base_gold_reward = gold_reward

	health = max_health
	update_health_bar()


func _process(delta: float) -> void:
	if dying:
		return

	if attacking:
		return

	if in_combat:
		# Atualiza o alvo caso tenha morrido ou ficado inválido.
		if not is_valid_combat_target(combat_target):
			combat_target = select_combat_target()

		if not is_instance_valid(combat_target):
			in_combat = false
			return

		# Mede a distância horizontal, ignorando a altura.
		var enemy_position := Vector2(
			global_position.x,
			global_position.z
		)

		var target_position := Vector2(
			combat_target.global_position.x,
			combat_target.global_position.z
		)

		var enemy_distance := enemy_position.distance_to(target_position)

		# Se o alvo sair do alcance, volta a persegui-lo.
		if enemy_distance > attack_range + 0.01:
			in_combat = false
			attack_timer = 0.0
			return

		attack_timer -= delta

		if attack_timer <= 0.0:
			attack()

		return

	# Persegue o herói vivo mais próximo.
	var target := get_nearest_hero()

	if not is_instance_valid(target):
		return

	var enemy_pos := Vector2(
		global_position.x,
		global_position.z
	)

	var target_pos := Vector2(
		target.global_position.x,
		target.global_position.z
	)

	var distance := enemy_pos.distance_to(target_pos)

	# Ao chegar ao alcance, fixa o alvo e inicia o combate.
	if distance <= attack_range + 0.01:
		combat_target = target
		start_combat()
		return

	
	# Continua perseguindo o herói.
	var direction := target.global_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.001:
		# Toca a animação de caminhada enquanto se movimenta.
		if animation_player.current_animation != "enemy/walk":
			animation_player.play("enemy/walk")

		# Mantém a orientação para o alvo.
		look_at_target(target)

		# Avança em direção ao herói.
		var step_distance: float = minf(
			speed * delta,
			maxf(distance - attack_range, 0.0)
		)

		global_position += direction.normalized() * step_distance




func is_valid_combat_target(target: Variant) -> bool:
	if not is_instance_valid(target):
		return false

	if not target is Node3D:
		return false

	if not target.is_inside_tree():
		return false

	if target.get("dead") == true:
		return false

	var target_health = target.get("health")

	if target_health != null and float(target_health) <= 0.0:
		return false

	return true



func select_combat_target() -> Node3D:
	var party_manager := get_tree().get_first_node_in_group(
		"party_manager"
	) as PartyManager

	print(
		"PartyManager encontrado: ",
		is_instance_valid(party_manager)
	)

	var nearest_hero: Node3D = null
	var nearest_distance: float = INF

	if is_instance_valid(party_manager):
		for hero in party_manager.get_alive_heroes():
			if not is_valid_combat_target(hero):
				continue

			var enemy_pos := Vector2(
				global_position.x,
				global_position.z
			)

			var hero_pos := Vector2(
				hero.global_position.x,
				hero.global_position.z
			)

			var distance := enemy_pos.distance_to(hero_pos)

			print(
				"Inimigo: ", name,
				" | Herói: ", hero.name,
				" | Distância: ", snappedf(distance, 0.01),
				" | Alcance: ", attack_range
			)

			if distance <= attack_range and distance < nearest_distance:
				nearest_distance = distance
				nearest_hero = hero

		if is_instance_valid(nearest_hero):
			print("Alvo selecionado: ", nearest_hero.name)

	if is_instance_valid(nearest_hero):
		return nearest_hero

	return null

func take_damage(damage: float, is_critical: bool = false) -> void:
	if dying:
		return

	health -= damage

	print(
		"INIMIGO: ", name,
		" | DAMAGE: ", damage,
		" | CRÍTICO: ", is_critical,
		" | HEALTH ATUAL: ", health,
		" | DYING: ", dying
	)

	flash_hit()
	update_health_bar()
	show_damage(damage, is_critical)

	if health <= 0.0:
		die()
		return

func die() -> void:
	print(
		"☠️ DIE INICIOU: ",
		name,
		" | HEALTH: ", health,
		" | DYING: ", dying
	)

	if dying:
		return

	dying = true
	in_combat = false
	attacking = false
	combat_target = null

	animation_player.play("enemy/die")

	# Desativa os colisores imediatamente.
	for child in get_children():
		if child is StaticBody3D:
			child.visible = false

	var level_controller = get_tree().get_first_node_in_group(
		"level_controller"
	)

	if is_instance_valid(level_controller):
		level_controller.enemy_died(self)

	health_bar_display.visible = false

	# Distribui as recompensas através do PartyManager.
	var party_manager := get_tree().get_first_node_in_group(
		"party_manager"
	) as PartyManager

	if is_instance_valid(party_manager):
		party_manager.grant_enemy_rewards(
			xp_reward,
			gold_reward
		)
	else:
		push_warning(
			"PartyManager não encontrado ao derrotar: " + name
		)


func attack() -> void:
	if attacking or dying:
		return

	# Revalida o alvo sem perder um alvo válido já selecionado.
	if not is_valid_combat_target(combat_target):
		combat_target = get_nearest_hero()

	if not is_instance_valid(combat_target):
		in_combat = false
		return

	var target: Node3D = combat_target

	# Mede a distância no plano X/Z.
	var enemy_pos := Vector2(
		global_position.x,
		global_position.z
	)

	var target_pos := Vector2(
		target.global_position.x,
		target.global_position.z
	)

	var distance := enemy_pos.distance_to(target_pos)

	if distance > attack_range + 0.01:
		in_combat = false
		attack_timer = 0.0
		return

	attacking = true
	attack_timer = attack_cooldown

	animation_player.play("enemy/attack")

	# Espera o momento do impacto.
	await get_tree().create_timer(attack_hit_delay).timeout

	if not is_instance_valid(self) or dying:
		return

	# Verifica se o alvo continua válido.
	if not is_valid_combat_target(target):
		attacking = false
		in_combat = false
		combat_target = null
		return

	# Confere novamente o alcance antes de aplicar o dano.
	enemy_pos = Vector2(
		global_position.x,
		global_position.z
	)

	target_pos = Vector2(
		target.global_position.x,
		target.global_position.z
	)

	distance = enemy_pos.distance_to(target_pos)

	if distance <= attack_range + 0.01:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

	attacking = false


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "enemy/attack":
		if not dying:
			attacking = false
			animation_player.play("enemy/idle")

	elif anim_name == "enemy/die":
		queue_free()

func show_damage(damage: float, is_critical: bool = false) -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()

	if tree == null:
		return

	var label := Label3D.new()

	
	label.font = DAMAGE_FONT
	label.font_size = damage_font_size
	label.outline_size = damage_outline_size
	label.outline_modulate = damage_outline_color

	if is_critical:
		label.text = "-" + str(int(damage)) + " CRITICAL!!"
		label.modulate = Color(1.0, 0.8, 0.0, 1.0) # Dourado
	else:
		label.text = "-" + str(int(damage))
		label.modulate = damage_color

	label.no_depth_test = true
	label.render_priority = 3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	add_child(label)
	label.top_level = true

	var start_position: Vector3 = global_position + Vector3(
		0.0,
		damage_height,
		0.0
	)

	label.global_position = start_position

	var direction := Vector3(
		randf_range(-1.0, 1.0),
		0.0,
		randf_range(-1.0, 1.0)
	).normalized()

	var horizontal_distance: float = randf_range(0.5, 1.0)
	var pop_height: float = randf_range(0.8, 1.4)

	var elapsed := 0.0

	while elapsed < damage_duration:
		if not is_instance_valid(self):
			return

		if not is_instance_valid(label):
			return

		if not is_inside_tree():
			label.queue_free()
			return

		elapsed += get_process_delta_time()

		var progress: float = clamp(
			elapsed / damage_duration,
			0.0,
			1.0
		)

		var horizontal_offset: Vector3 = (
			direction * horizontal_distance * progress
		)

		var vertical_offset: float = sin(PI * progress) * pop_height

		label.global_position = (
			start_position
			+ horizontal_offset
			+ Vector3(0.0, vertical_offset, 0.0)
		)

		await tree.process_frame

	if is_instance_valid(label):
		label.queue_free()

func update_health_bar() -> void:
	if not is_instance_valid(health_bar):
		return

	health_bar.max_value = max_health
	health_bar.value = clampf(health, 0.0, max_health)


func start_combat() -> void:
	if dying or health <= 0.0:
		return

	# Preserva o alvo que já foi escolhido pela perseguição.
	if not is_valid_combat_target(combat_target):
		combat_target = get_nearest_hero()

	if not is_instance_valid(combat_target):
		return

	in_combat = true
	attacking = false
	attack_timer = 0.0

	animation_player.speed_scale = 1.0
	animation_player.play("enemy/idle")


func flash_hit() -> void:
	var meshes = find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)

	for i in range(2):
		for mesh in meshes:
			var material = mesh.get_active_material(0)

			if material:
				var flash_material = material.duplicate()

				flash_material.albedo_color = Color(
					1.0,
					0.03,
					0.03,
					1.0
				)

				flash_material.emission_enabled = true
				flash_material.emission = Color(
					1.0,
					0.0,
					0.0,
					1.0
				)

				flash_material.emission_energy_multiplier = 3.0
				mesh.material_override = flash_material

		await get_tree().create_timer(0.08).timeout

		for mesh in meshes:
			if is_instance_valid(mesh):
				mesh.material_override = null

		await get_tree().create_timer(0.05).timeout


func setup_level(level: int) -> void:
	# Captura os valores originais do Inspector.
	base_max_health = max_health
	base_attack_damage = attack_damage
	base_xp_reward = xp_reward
	base_gold_reward = gold_reward

	enemy_level = maxi(1, level)

	var level_multiplier: int = enemy_level - 1

	max_health = base_max_health * (
		1.0 + health_per_level * level_multiplier
	)

	attack_damage = base_attack_damage * (
		1.0 + damage_per_level * level_multiplier
	)

	xp_reward = roundi(
		base_xp_reward *
		(1.0 + xp_per_level * level_multiplier)
	)

	gold_reward = roundi(
		base_gold_reward *
		(1.0 + gold_per_level * level_multiplier)
	)

	health = max_health

	update_health_bar()
	create_level_label()

	print(
		"=== INIMIGO CONFIGURADO ===",
		" | Nome: ", name,
		" | Nível: ", enemy_level,
		" | Vida: ", max_health,
		" | Dano: ", attack_damage,
		" | XP: ", xp_reward,
		" | Ouro: ", gold_reward
	)


func create_level_label() -> void:
	if is_instance_valid(level_label):
		level_label.queue_free()

	level_label = Label3D.new()

	level_label.name = "LevelLabel"
	level_label.text = "Lv. " + str(enemy_level)

	level_label.font = DAMAGE_FONT
	level_label.font_size = level_label_font_size
	level_label.modulate = level_label_color
	level_label.outline_size = level_label_outline_size
	level_label.outline_modulate = level_label_outline_color

	level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_label.no_depth_test = true
	level_label.render_priority = 3

	level_label.font_size = 50
	level_label.fixed_size = true
	level_label.pixel_size = 0.002

	add_child(level_label)

	level_label.position = Vector3(
		0.0,
		level_label_height,
		0.0
	)


func get_nearest_hero() -> Node3D:
	var party_manager := get_tree().get_first_node_in_group(
		"party_manager"
	) as PartyManager

	if not is_instance_valid(party_manager):
		return player if is_valid_combat_target(player) else null

	var nearest_hero: Node3D = null
	var nearest_distance: float = INF

	for hero in party_manager.get_alive_heroes():
		if not is_valid_combat_target(hero):
			continue

		var enemy_pos := Vector2(
			global_position.x,
			global_position.z
		)

		var hero_pos := Vector2(
			hero.global_position.x,
			hero.global_position.z
		)

		var distance := enemy_pos.distance_to(hero_pos)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_hero = hero

	if is_instance_valid(nearest_hero):
		return nearest_hero

	return player if is_valid_combat_target(player) else null


func look_at_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	var target_position := target.global_position
	target_position.y = global_position.y

	if global_position.distance_squared_to(target_position) < 0.001:
		return

	look_at(target_position, Vector3.UP)
	rotate_y(PI)
