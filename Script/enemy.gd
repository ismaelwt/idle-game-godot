
extends Node3D
class_name Enemy

@export_category("Movimento")
@export var speed: float = 2.0
@export var radius: float = 5.0

@export_category("Alvo")
@export var target_height: float = 1.5

@export_category("Vida")
@export var max_health: float = 15.0

@export_category("Level Scaling")
@export var enemy_level: int = 1
@export var health_per_level: float = 0.18
@export var damage_per_level: float = 0.07
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
@export var approach_enabled: bool = true
@export var projectile_scene: PackedScene

@export_category("Animações")
@export var idle_animation: StringName = &"enemy/idle"
@export var walk_animation: StringName = &"enemy/walk"
@export var attack_animation: StringName = &"enemy/attack"
@export var death_animation: StringName = &"enemy/die"

const DAMAGE_FONT: Font = preload("res://Fonts/Pix32.ttf")
const GOLD_ICON: Texture2D = preload("res://icons/coins.png")
const GOLD_DROP_SOUND: AudioStream = preload("res://Sounds/drop_coin.mp3")

@onready var animation_player = $AnimationPlayer
@onready var health_bar: ProgressBar = $SubViewport/ProgressBar
@onready var health_bar_display: Sprite3D = $HealthBarDisplay

var fallback_hero_target: Node3D
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

	animation_player.play(walk_animation)

	center_position = global_position

	base_max_health = max_health
	base_attack_damage = attack_damage
	base_xp_reward = xp_reward
	base_gold_reward = gold_reward

	health = max_health

func _process(delta: float) -> void:
	var melee_behavior := get_node_or_null("EnemyBehavior")
	if is_instance_valid(melee_behavior):
		melee_behavior.call("update_behavior", delta)




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

	show_gold_reward()
	animation_player.play(death_animation)

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
	var melee_behavior := get_node_or_null("EnemyBehavior")
	if is_instance_valid(melee_behavior):
		melee_behavior.call("attack")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == attack_animation:
		if not dying:
			attacking = false
			animation_player.play(idle_animation)

	elif anim_name == death_animation:
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


func play_gold_drop_sound() -> void:
	if not is_inside_tree():
		return

	var audio_parent: Node = get_tree().current_scene
	if audio_parent == null:
		audio_parent = get_parent()

	if audio_parent == null:
		return

	var audio_player := AudioStreamPlayer3D.new()
	audio_player.name = "GoldDropSound"
	audio_player.stream = GOLD_DROP_SOUND
	audio_parent.add_child(audio_player)
	audio_player.global_position = global_position
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play()


func show_gold_reward() -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	play_gold_drop_sound()

	var reward_visual := Node3D.new()
	reward_visual.name = "GoldRewardVisual"
	add_child(reward_visual)
	reward_visual.top_level = true

	var coin_icon := Sprite3D.new()
	coin_icon.texture = GOLD_ICON
	coin_icon.pixel_size = 0.01
	coin_icon.modulate = Color.WHITE
	coin_icon.no_depth_test = true
	coin_icon.render_priority = 3
	coin_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reward_visual.add_child(coin_icon)

	var amount_label := Label3D.new()
	amount_label.font = DAMAGE_FONT
	amount_label.font_size = 100
	amount_label.outline_size = damage_outline_size
	amount_label.outline_modulate = damage_outline_color
	amount_label.text = "(" + str( int(gold_reward))  + ")"
	amount_label.modulate = Color(1.0, 0.8, 0.0, 1.0)
	amount_label.no_depth_test = true
	amount_label.render_priority = 3
	amount_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reward_visual.add_child(amount_label)

	# Posiciona os elementos no eixo horizontal da câmera,
	# para que fiquem lado a lado também na visão isométrica.
	var camera := get_viewport().get_camera_3d()
	var screen_right := Vector3.RIGHT
	if is_instance_valid(camera):
		screen_right = camera.global_basis.x.normalized()

	coin_icon.position = reward_visual.to_local(
		reward_visual.global_position - screen_right * 0.50
	)
	amount_label.position = reward_visual.to_local(
		reward_visual.global_position + screen_right * 0.50
	)

	var start_position: Vector3 = global_position + Vector3(
		0.0,
		damage_height + 2.0,
		0.0
	)
	reward_visual.global_position = start_position

	var rise_height: float = 1.5
	var elapsed := 0.0

	while elapsed < damage_duration:
		if not is_instance_valid(reward_visual):
			return

		if not is_inside_tree():
			reward_visual.queue_free()
			return

		elapsed += get_process_delta_time()
		var progress: float = clamp(
			elapsed / damage_duration,
			0.0,
			1.0
		)

		# Sobe continuamente, sem deslocamento lateral, e desaparece gradualmente.
		reward_visual.global_position = (
			start_position + Vector3(0.0, rise_height * progress, 0.0)
		)

		var alpha: float = 1.0 - progress
		coin_icon.modulate.a = alpha
		amount_label.modulate.a = alpha

		await tree.process_frame

	if is_instance_valid(reward_visual):
		reward_visual.queue_free()

func update_health_bar() -> void:
	if not is_instance_valid(health_bar):
		return

	health_bar.max_value = max_health
	health_bar.value = clampf(health, 0.0, max_health)


func start_combat() -> void:
	var melee_behavior := get_node_or_null("EnemyBehavior")
	if is_instance_valid(melee_behavior):
		melee_behavior.call("start_combat")


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
		return fallback_hero_target if is_valid_combat_target(fallback_hero_target) else null

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

	return fallback_hero_target if is_valid_combat_target(fallback_hero_target) else null


func look_at_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	var target_position := target.global_position
	target_position.y = global_position.y

	if global_position.distance_squared_to(target_position) < 0.001:
		return

	look_at(target_position, Vector3.UP)
	rotate_y(PI)
