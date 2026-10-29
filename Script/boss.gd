extends Node3D


@export_category("Movimento")
@export var speed: float = 3.0
@export var radius: float = 5.0


@export_category("Alvo")
@export var target_height: float = 2.0


@export_category("Vida")
@export var max_health: float = 100.0


@export_category("Level Scaling")
@export var boss_level: int = 1

@export var health_per_level: float = 0.25
@export var damage_per_level: float = 0.12
@export var xp_per_level: float = 0.20
@export var gold_per_level: float = 0.10

var base_max_health: float
var base_attack_damage: float
var base_xp_reward: int
var base_gold_reward: int


@export_category("Level Label")
@export var level_label_font_size: int = 50
@export var level_label_height: float = -0.3
@export var level_label_color: Color = Color.WHITE
@export var level_label_outline_size: int = 6
@export var level_label_outline_color: Color = Color.BLACK

var level_label: Label3D


@export_category("Recompensa")
@export var xp_reward: int = 220
@export var gold_reward: int = 50


@export_category("Dano Visual")
@export var damage_font_size: int = 128
@export var damage_outline_size: int = 8
@export var damage_height: float = 2.5
@export var damage_end_height: float = 2.9
@export var damage_duration: float = 1.0
@export var damage_rise_speed: float = 3.0
@export var damage_color: Color = Color.WHITE
@export var damage_outline_color: Color = Color.BLACK


@export_category("Ataque")
@export var attack_range: float = 3.0
@export var attack_cooldown: float = 1.5
@export var attack_damage: float = 12.0
@export var attack_hit_delay: float = 1.0


@export_category("Ataque Especial")
@export_range(1.0, 10.0, 0.5)
var special_attack_damage_multiplier: float = 2.0

@export_range(0.0, 1.0, 0.05)
var special_attack_health_threshold: float = 0.5


const DAMAGE_FONT: Font = preload("res://Fonts/Pix32.ttf")

@onready var animation_player = $AnimationPlayer
@onready var health_bar: ProgressBar = $SubViewport/ProgressBar

@onready var party_manager: PartyManager = (
	get_tree().get_first_node_in_group("party_manager")
)

@onready var level_controller: Node = (
	get_tree().get_first_node_in_group("level_controller")
)


var fallback_hero_target: Node3D

var health: float
var center_position: Vector3
var angle: float = 0.0

var attacking := false
var dying := false
var in_combat := false

var attack_timer: float = 0.0

var special_attack_used := true
var special_attack_in_progress := false
var special_impact_instance: Node3D


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)

	animation_player.play("enemy/walk")

	center_position = global_position
	health = max_health

	update_health_bar()


func _process(delta: float) -> void:
	if dying:
		return

	if attacking:
		return

	var target: Node3D = get_nearest_alive_hero()

	if not is_instance_valid(target):
		in_combat = false
		return

	
	if in_combat:
		var enemy_pos := Vector2(
			global_position.x,
			global_position.z
		)

		var target_pos := Vector2(
			target.global_position.x,
			target.global_position.z
		)
		
		var targer_distance := enemy_pos.distance_to(target_pos)

		# Se o novo herói estiver fora do alcance,
		# o Boss volta a persegui-lo.
		if targer_distance > attack_range + 0.01:
			in_combat = false
			attack_timer = 0.0
			return

		attack_timer -= delta

		if attack_timer <= 0.0:
			attack()

		return


	# Fora de combate, o Boss persegue o herói vivo mais próximo.
	var direction: Vector3 = target.global_position - global_position
	direction.y = 0.0

	var distance: float = Vector2(
		direction.x,
		direction.z
	).length()

	# Ao chegar ao alcance, inicia o combate.
	if distance <= attack_range:
		if animation_player.current_animation != "enemy/idle":
			animation_player.play("enemy/idle")

		start_combat()
		return

	# Enquanto estiver se movimentando, toca a animação de caminhada.
	if direction.length_squared() > 0.001:
		if animation_player.current_animation != "enemy/walk":
			animation_player.play("enemy/walk")

		# Mantém o movimento horizontal em direção ao alvo.
		global_position += direction.normalized() * speed * delta



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

func _check_special_attack() -> void:
	if dying:
		return

	if special_attack_used:
		return

	if max_health <= 0.0:
		return

	var health_threshold: float = (
		max_health * special_attack_health_threshold
	)

	if health <= health_threshold:
		special_attack_used = true
		special_attack_in_progress = true
		attacking = true

		attack_timer = attack_cooldown

		animation_player.play("enemy/boss_especial_attack")

		await get_tree().create_timer(attack_hit_delay).timeout

		if not is_inside_tree():
			return

		if dying:
			return

		var target: Node3D = get_nearest_alive_hero()

		if not is_instance_valid(target):
			special_attack_in_progress = false
			attacking = false
			return

		var special_damage: float = (
			attack_damage * special_attack_damage_multiplier
		)

		if target.has_method("take_damage"):
			target.take_damage(special_damage)


func die() -> void:
	print(
		"☠️ DIE INICIOU: ",
		name,
		" | HEALTH: ",
		health,
		" | DYING: ",
		dying
	)

	if dying:
		return

	dying = true
	in_combat = false
	attacking = false
	special_attack_in_progress = false

	animation_player.play("enemy/die")
	
	if is_instance_valid(level_controller):
		if level_controller.has_method("enemy_died"):
			level_controller.enemy_died(self)
		else:
			push_warning("LevelController não possui o método enemy_died().")
	else:
		push_warning("LevelController não encontrado ao derrotar o boss: " + name)

	for child in get_children():
		if child is StaticBody3D:
			child.visible = false
	
	# Distribui as recompensas através do PartyManager.
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

	var target: Node3D = get_nearest_alive_hero()

	if not is_instance_valid(target):
		in_combat = false
		attack_timer = 0.0
		return

	# Confere a distância antes de iniciar o ataque.
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

	if not is_inside_tree() or dying:
		return

	# O herói pode ter morrido durante a animação.
	if not is_instance_valid(target) or bool(target.get("dead")):
		attacking = false
		in_combat = false
		attack_timer = 0.0
		return

	# Recalcula a distância no momento do impacto.
	enemy_pos = Vector2(
		global_position.x,
		global_position.z
	)

	target_pos = Vector2(
		target.global_position.x,
		target.global_position.z
	)

	distance = enemy_pos.distance_to(target_pos)

	if distance <= attack_range:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

	attacking = false



func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "enemy/attack":
		attacking = false
		animation_player.play("enemy/idle")

	elif anim_name == "enemy/boss_especial_attack":
		special_attack_in_progress = false
		attacking = false

		if is_instance_valid(special_impact_instance):
			special_impact_instance.queue_free()
			special_impact_instance = null

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

	label.text = "-" + str(int(damage))
	label.font = DAMAGE_FONT
	label.font_size = damage_font_size
	label.outline_size = damage_outline_size
	label.outline_modulate = damage_outline_color

	if is_critical:
		label.modulate = Color(1.0, 0.8, 0.0, 1.0) # Dourado
	else:
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


func get_nearest_alive_hero() -> Node3D:
	var heroes: Array[Node3D] = []

	if is_instance_valid(party_manager):
		heroes = party_manager.get_alive_heroes()
	else:
		var fallback_hero: Node3D = _get_selected_hero_fallback()
		if is_instance_valid(fallback_hero) and not bool(fallback_hero.get("dead")):
			heroes.append(fallback_hero)

	var nearest_hero: Node3D = null
	var nearest_distance: float = INF

	for hero in heroes:
		if not is_instance_valid(hero):
			continue

		if bool(hero.get("dead")):
			continue

		var distance: float = Vector2(
			hero.global_position.x - global_position.x,
			hero.global_position.z - global_position.z
		).length()

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_hero = hero

	return nearest_hero


func start_combat() -> void:
	if dying:
		return

	if health <= 0.0:
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
	# Captura os valores originais configurados no Inspector.
	base_max_health = max_health
	base_attack_damage = attack_damage
	base_xp_reward = xp_reward
	base_gold_reward = gold_reward

	boss_level = maxi(1, level)

	var level_multiplier: int = boss_level - 1

	max_health = base_max_health * (
		1.0 + health_per_level * level_multiplier
	)

	attack_damage = base_attack_damage * (
		1.0 + damage_per_level * level_multiplier
	)

	xp_reward = roundi(
		base_xp_reward * (
			1.0 + xp_per_level * level_multiplier
		)
	)

	gold_reward = roundi(
		base_gold_reward * (
			1.0 + gold_per_level * level_multiplier
		)
	)

	health = max_health

	create_level_label()

	print(
		"=== BOSS CONFIGURADO ===",
		" | Nome: ", name,
		" | Nível: ", boss_level,
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
	level_label.text = "Lv. " + str(boss_level)

	level_label.font = DAMAGE_FONT
	level_label.font_size = level_label_font_size
	level_label.modulate = level_label_color
	level_label.outline_size = level_label_outline_size
	level_label.outline_modulate = level_label_outline_color

	level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_label.no_depth_test = true
	level_label.render_priority = 3
	level_label.fixed_size = true
	level_label.pixel_size = 0.002

	add_child(level_label)

	level_label.position = Vector3(
		0.0,
		level_label_height,
		0.0
	)



func _get_selected_hero_fallback() -> Node3D:
	var selected_id := CharacterSelectionData.get_selected_character_id()
	for candidate in get_tree().get_nodes_in_group("party_heroes"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var stats = candidate.get("character_stats")
		if not is_instance_valid(stats):
			stats = candidate.get_node_or_null("CharacterStats")
		if is_instance_valid(stats):
			var hero_id := CharacterSelectionData.normalize_hero_id(str(stats.get("hero_id")))
			if hero_id == selected_id:
				return candidate
	return null
