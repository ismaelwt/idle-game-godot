extends Node3D


@export_category("Movimento")
@export var speed: float = 0.5
@export var radius: float = 5.0


@export_category("Alvo")
@export var target_height: float = 1.5


@export_category("Vida")
@export var max_health: float = 100.0

@export_category("Recompensa")
@export var xp_reward: int = 25
@export var gold_reward: int = 10

@export_category("Barra de Vida")
@export var health_bar_font_size: int = 32
@export var health_bar_outline_size: int = 6
@export var health_bar_offset: float = 0.3
@export var health_bar_blocks: int = 12
@export var health_bar_color: Color = Color(1, 0.0, 0.0, 1)


@export_category("Dano Visual")
@export var damage_font_size: int = 48
@export var damage_outline_size: int = 8
@export var damage_height: float = 2.5
@export var damage_end_height: float = 3.5
@export var damage_duration: float = 0.7
@export var damage_rise_speed: float = 1.5
@export var damage_color: Color = Color(1, 0.2, 0.2, 1)


@export_category("Ataque")
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 2.0
@export var attack_damage: float = 10.0
@export var attack_hit_delay: float = 2.0

const DAMAGE_FONT: Font = preload("res://Fonts/Pix32.ttf")
@onready var animation_player = $Animationherói


var target_hero: Node3D

var health: float
var center_position: Vector3
var angle: float = 0.0

var attacking := false
var dying := false
var in_combat := false

var attack_timer: float = 0.0

var health_bar_background: Label3D
var health_bar: Label3D
var health_value_label: Label3D


func _ready():

	animation_player.animation_finished.connect(_on_animation_finished)

	animation_player.play("Armature|walk")

	center_position = global_position
	health = max_health

	create_health_bar()
	update_health_bar()


func _process(delta):

	if dying:
		return


	if attacking:
		return


	# ==========================================
	# COMBATE
	# ==========================================

	if in_combat:

		attack_timer -= delta

		if attack_timer <= 0.0:

			attack()

		return


	# ==========================================
	# MOVIMENTO
	# ==========================================

	if not is_instance_valid(target_hero):
		return


	# Movimento em direção ao herói.
	var direction = global_position.direction_to(
		target_hero.global_position
	)


	# Movimento somente no chão.
	direction.y = 0.0


	if direction.length() > 0.01:

		global_position += direction.normalized() * speed * delta


func take_damage(damage: float):

	if dying:
		return

	health -= damage
	print(
			"INIMIGO: ",
			name,
			" | DAMAGE: ",
			damage,
			" | HEALTH ATUAL: ",
			health,
			" | DYING: ",
			dying
		)
	flash_hit()

	update_health_bar()

	show_damage(damage)

	if health <= 0:

		die()

		return

	# ==========================================
	# ANIMAÇÃO DE HIT
	# ==========================================

	if not attacking:
		if animation_player.has_animation("Armature|hit"):
			animation_player.play(
				"Armature|hit",
				0.15
			)


func die():
	
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
	animation_player.play("Armature|die")
	# Desativa os colisores imediatamente.
	for child in get_children():

		if child is StaticBody3D:
			child.visible = false
			
	var level_controller = get_tree().get_first_node_in_group(
		"level_controller"
	)

	if level_controller:
		level_controller.enemy_died(self)

	target_hero = _get_nearest_alive_hero()

	if is_instance_valid(target_hero):
		target_hero.character_stats.add_xp(xp_reward)
		target_hero.character_stats.add_gold(gold_reward)
		SaveManager.save_character(target_hero.character_stats)

	# A animação de morte continua.
	


func attack():

	if attacking or dying:
		return

	attacking = true

	# Reinicia o contador para o próximo ataque.
	attack_timer = attack_cooldown

	# ==========================================
	# ALVO
	# ==========================================

	var target_hero = _get_nearest_alive_hero()

	if not is_instance_valid(target_hero):
		attacking = false
		return

	if target_player.dead:
		attacking = false
		return

	# ==========================================
	# ANIMAÇÃO
	# ==========================================

	animation_player.play("Armature|attack")

	# Tempo entre o início da animação e o dano
	await get_tree().create_timer(attack_hit_delay).timeout

	# ==========================================
	# VERIFICAÇÕES
	# ==========================================

	if dying:
		return

	if not is_instance_valid(target_player):
		return

	if target_player.dead:
		return

	# ==========================================
	# DANO
	# ==========================================

	target_player.take_damage(attack_damage)
	


func _on_animation_finished(anim_name):

	if anim_name == "Armature|attack":

		attacking = false

		animation_player.play("Armature|idle")


	elif anim_name == "Armature|hit":

		if dying:
			return

		if attacking:
			return

		if in_combat:
			animation_player.play("Armature|idle")
		else:
			animation_player.play("Armature|walk")
	elif anim_name == "Armature|die":
		queue_free()



func show_damage(damage: float):

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
	label.modulate = damage_color

	label.no_depth_test = true
	label.render_priority = 3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	add_child(label)
	label.top_level = true

	label.global_position = (
		global_position +
		Vector3(0, damage_height, 0)
	)

	var elapsed := 0.0

	while elapsed < damage_duration:

		# O inimigo ou a label podem ter sido removidos.
		if not is_instance_valid(self):
			return

		if not is_instance_valid(label):
			return

		if not is_inside_tree():
			label.queue_free()
			return

		if tree == null:
			label.queue_free()
			return

		var delta := get_process_delta_time()
		elapsed += delta

		label.global_position.y += damage_rise_speed * delta

		label.modulate.a = 1.0 - (elapsed / damage_duration)

		await tree.process_frame

	if is_instance_valid(label):
		label.queue_free()



func create_health_bar():

	# FUNDO PRETO
	health_bar_background = Label3D.new()
	health_bar_background.text = "■".repeat(health_bar_blocks)
	health_bar_background.font_size = health_bar_font_size
	health_bar_background.outline_size = health_bar_outline_size
	health_bar_background.no_depth_test = true
	health_bar_background.render_priority = 1
	health_bar_background.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_background.modulate = Color.BLACK
	health_bar_background.position = Vector3(
		0,
		target_height + health_bar_offset,
		0
	)
	add_child(health_bar_background)

	# VIDA VERMELHA
	health_bar = Label3D.new()
	health_bar.font_size = health_bar_font_size
	health_bar.outline_size = health_bar_outline_size
	health_bar.no_depth_test = true
	health_bar.render_priority = 2
	health_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar.modulate = health_bar_color
	health_bar.position = Vector3(
		0,
		target_height + health_bar_offset,
		0
	)
	add_child(health_bar)

	# VALOR NUMÉRICO DA VIDA
	health_value_label = Label3D.new()
	health_value_label.font = DAMAGE_FONT
	health_value_label.font_size = 64
	health_value_label.outline_size = 5
	health_value_label.no_depth_test = true
	health_value_label.render_priority = 3
	health_value_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_value_label.modulate = Color.WHITE
	health_value_label.position = Vector3(
		0,
		target_height + health_bar_offset - 0.35,
		0
	)
	add_child(health_value_label)

	update_health_bar()



func update_health_bar():

	if not is_instance_valid(health_bar):
		return

	var percent = clamp(health / max_health, 0.0, 1.0)
	var filled_blocks = int(round(percent * health_bar_blocks))

	health_bar.text = "█".repeat(filled_blocks)



func start_combat():
	
	if dying:
		return

	if health <= 0:
		return

	# Agora significa que o inimigo
	# chegou no próprio alcance.
	in_combat = true

	attacking = false

	# Permite atacar imediatamente.
	attack_timer = 0.0

	animation_player.speed_scale = 1.0

	animation_player.play("Armature|idle")

func flash_hit():

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


func _get_nearest_alive_hero() -> Node3D:
	var manager := get_tree().get_first_node_in_group("party_manager") as PartyManager
	if is_instance_valid(manager):
		var heroes := manager.get_alive_heroes()
		var nearest: Node3D = null
		var nearest_distance := INF
		for hero in heroes:
			if not is_instance_valid(hero) or bool(hero.get("dead")):
				continue
			var distance := global_position.distance_to(hero.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = hero
		if is_instance_valid(nearest):
			return nearest

	var selected_id := CharacterSelectionData.get_selected_character_id()
	for candidate in get_tree().get_nodes_in_group("party_heroes"):
		if not is_instance_valid(candidate) or bool(candidate.get("dead")):
			continue
		var stats = candidate.get("character_stats")
		if not is_instance_valid(stats):
			stats = candidate.get_node_or_null("CharacterStats")
		if is_instance_valid(stats) and CharacterSelectionData.normalize_hero_id(str(stats.get("hero_id"))) == selected_id:
			return candidate
	return null
