
extends Node3D

@export_category("Animações")
@export var idle_animation: StringName = &"knight/idle"
@export var running_animation: StringName = &"knight/running"
@export var attack_animation: StringName = &"knight/attack"

@export_category("Configuração")
@export var animation_speed: float = 1.0
@export var animation_blend: float = 0.35
@export var movement_speed: float = 3.0

@export_category("Detecção e Ataque")
@export var attack_range: float = 3.0 # Raio para detectar inimigos próximos
@export var melee_range: float = 2.5 # Distância máxima para acertar o ataque
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var attack_hit_delay: float = 0.45

@onready var animation_player = $AnimationPlayer
@onready var character_stats = $CharacterStats
@onready var level_up_effect = $LevelUpEffect

@onready var level_controller: Node = get_parent().get_node_or_null("LevelController")
@onready var world_scroller: Node = get_parent().get_node_or_null("World/WorldScroller")
@onready var enemy_spawner: Node = get_parent().get_node_or_null("EnemySpawner")

@export_category("Vida")
@export var max_health: float = 150.0

@export_category("Dano Visual")
@export var damage_font_size: int = 48
@export var damage_outline_size: int = 8
@export var damage_height: float = 2.5
@export var damage_duration: float = 0.7
@export var damage_color: Color = Color(1.0, 0.2, 0.2, 1.0)


const DAMAGE_FONT: Font = preload("res://Fonts/Pix32.ttf")

var health: float = 0.0
var dead: bool = false

var initial_rotation_y: float

var current_animation: StringName = &""
var warned_animations: Dictionary = {}

var attacking: bool = false
var attack_timer: float = 0.0
var current_attack_target: Node3D = null
var attack_id: int = 0

var action_locked := false
var skill_animation_finished = false
var attack_animation_playing := false
var is_running := false
var basic_attack_lock := false
var frenzy_active: bool = false
var frenzy_instance: Node3D = null
var is_returning_to_initial_position: bool = false


func _ready() -> void:
	SaveManager.load_character(
		character_stats,
		character_stats.inventory,
		str(character_stats.hero_id)
	)

	max_health = 150.0 + character_stats.get_max_health_bonus()
	health = max_health
	
	character_stats.mana = character_stats.max_mana
	character_stats.mana_regen_timer = 0.0

	animation_player.speed_scale = animation_speed
	initial_rotation_y = rotation.y

	# Mantenha abaixo deste ponto o restante
	# da inicialização original do Cavaleiro.

	if level_controller == null:
		push_warning("Knight: LevelController não encontrado.")

	if world_scroller == null:
		push_warning("Knight: WorldScroller não encontrado.")
	animation_player.animation_finished.connect(on_animation_finished)
	character_stats.level_up_occurred.connect(play_level_up_effect)
	character_stats.attributes_changed.connect(_on_attributes_changed)
	play_animation(idle_animation)

func _process(delta: float) -> void:
	if dead or not is_instance_valid(level_controller):
		return

	if attacking or is_returning_to_initial_position:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)

	var combat_controller = get_parent().get_node_or_null("CombatController")
	var target: Node3D = null

	if is_instance_valid(combat_controller):
		target = combat_controller.get_valid_target_for_hero(self)

	if not is_instance_valid(target):
		target = find_nearest_enemy_in_detection_range()

	if not is_instance_valid(target):
		var current_enemy = level_controller.current_enemy
		if is_instance_valid(current_enemy):
			target = current_enemy

	if not is_instance_valid(target):
		if is_instance_valid(world_scroller) and world_scroller.running:
			play_animation(running_animation)
		else:
			play_animation(idle_animation)
		return

	if not target.is_inside_tree():
		play_animation(idle_animation)
		return

	if not target.has_method("take_damage"):
		play_animation(idle_animation)
		return

	if target.get("dying") == true or target.get("health") <= 0:
		play_animation(idle_animation)
		return

	# Enquanto o mundo avança, mantém a animação de corrida.
	if is_instance_valid(world_scroller) and world_scroller.running:
		play_animation(running_animation)
		return

	# Calcula a distância horizontal atual.
	var target_position: Vector3 = target.global_position
	var knight_position: Vector3 = global_position

	var direction := Vector3(
		target_position.x - knight_position.x,
		0.0,
		target_position.z - knight_position.z
	)

	var distance: float = direction.length()

	# Fora do alcance: o Knight precisa avançar fisicamente.
	if distance > melee_range + 0.01:
		play_animation(running_animation)
		look_at_target(target)

		if distance > 0.001:
			var remaining_distance: float = distance - melee_range
			var step_distance: float = minf(
				get_movement_speed() * delta,
				remaining_distance
			)

			var movement: Vector3 = direction.normalized() * step_distance

			# Move apenas nos eixos horizontais, preservando a altura.
			global_position = Vector3(
				global_position.x + movement.x,
				global_position.y,
				global_position.z + movement.z
			)

		return

	# Dentro do alcance: para de avançar.
	# Durante o combate, o CombatController decide entre skill e ataque básico.
	look_at_target(target)

	if is_instance_valid(combat_controller) and combat_controller.combat_active:
		return

	if attack_timer <= 0.0:
		basic_attack(target)
	else:
		play_animation(idle_animation)

func use_skill(skill_id: String, target: Node3D) -> void:
	if dead or action_locked or attacking:
		return

	if not is_instance_valid(target):
		return

	if target.get("dying") == true or target.get("health") == null or target.get("health") <= 0:
		return

	if not SkillTree.has_skill(skill_id):
		push_warning("Knight: skill não encontrada: " + skill_id)
		return

	var skill_data: Dictionary = SkillTree.get_skill(skill_id)
	if not skill_data.has("scene"):
		push_warning("Knight: a skill não possui uma cena configurada: " + skill_id)
		return

	if skill_id != "frenesi":
		push_warning("Knight: skill ainda não implementada: " + skill_id)
		return

	var skill_scene: PackedScene = skill_data["scene"]
	if skill_scene == null:
		push_warning("Knight: cena inválida para a skill: " + skill_id)
		return

	if is_instance_valid(frenzy_instance):
		frenzy_instance.queue_free()
		frenzy_instance = null

	look_at_target(target)
	attacking = true
	action_locked = true
	current_attack_target = null
	attack_id += 1
	var my_attack_id: int = attack_id

	frenzy_instance = skill_scene.instantiate() as Node3D
	if not is_instance_valid(frenzy_instance):
		attacking = false
		action_locked = false
		push_warning("Knight: não foi possível instanciar a skill " + skill_id)
		return

	add_child(frenzy_instance)
	frenzy_instance.position = Vector3.ZERO
	frenzy_instance.scale = Vector3(2.5, 2.5, 2.5)
	frenzy_active = true
	print("KNIGHT USANDO SKILL: ", skill_id)
	
	animation_player.speed_scale = 1.0
	animation_player.play("knight/buff", 0.2)

	await animation_player.animation_finished

	
	# Duração e multiplicador são lidos da própria cena da skill.
	var duration_value = frenzy_instance.get("duration")
	if duration_value == null:
		frenzy_active = false
		frenzy_instance.queue_free()
		frenzy_instance = null
		attacking = false
		action_locked = false
		push_warning("Knight: a cena da skill não define 'duration'.")
		return

	attacking = false
	action_locked = false
	await get_tree().create_timer(float(duration_value)).timeout

	if my_attack_id != attack_id:
		return

	frenzy_active = false
	if is_instance_valid(frenzy_instance):
		frenzy_instance.queue_free()
	frenzy_instance = null
	print("KNIGHT SKILL FINALIZADA: ", skill_id)


func find_nearest_enemy_in_detection_range() -> Node3D:
	if not is_instance_valid(enemy_spawner):
		return null

	var nearest_enemy: Node3D = null
	var nearest_distance: float = attack_range

	for enemy in enemy_spawner.enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.dying or enemy.health <= 0:
			continue

		var distance := get_horizontal_distance_to(enemy)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy


func get_horizontal_distance_to(target: Node3D) -> float:
	if not is_instance_valid(target):
		return INF

	var knight_pos := Vector2(global_position.x, global_position.z)
	var target_pos := Vector2(target.global_position.x, target.global_position.z)

	return knight_pos.distance_to(target_pos)


func get_movement_speed() -> float:
	return maxf(movement_speed, 0.0)


func basic_attack(target: Node3D) -> void:
	if dead or attacking or action_locked:
		return

	# Respeita o intervalo entre ataques.
	if attack_timer > 0.0:
		return

	if not is_instance_valid(target):
		return

	if target.get("dying") == true:
		return

	var target_health = target.get("health")
	if target_health == null or float(target_health) <= 0.0:
		return

	if get_horizontal_distance_to(target) > melee_range + 0.01:
		return

	attacking = true

	var attack_interval_multiplier: float = (
		character_stats.get_basic_attack_interval_multiplier()
	)

	attack_timer = attack_cooldown * attack_interval_multiplier
	current_attack_target = target

	attack_id += 1
	var my_attack_id := attack_id

	look_at_target(target)

	animation_player.speed_scale = animation_speed
	play_animation(attack_animation)

	print("=== KNIGHT ATAQUE INICIADO ===")
	print("Alvo: ", target.name)

	await get_tree().create_timer(attack_hit_delay).timeout

	if my_attack_id != attack_id:
		return

	if dead or not is_instance_valid(target):
		_finish_attack()
		return

	if target.get("dying") == true:
		_finish_attack()
		return

	target_health = target.get("health")
	if target_health == null or float(target_health) <= 0.0:
		_finish_attack()
		return

	if get_horizontal_distance_to(target) > melee_range + 0.01:
		_finish_attack()
		return

	if target.has_method("take_damage"):
		var physical_bonus: float = (
			character_stats.get_physical_damage_bonus()
		)

		var raw_damage: float = (
			attack_damage
			+ character_stats.get_weapon_damage_bonus()
			+ physical_bonus
		)

		if frenzy_active and is_instance_valid(frenzy_instance):
			var damage_multiplier = frenzy_instance.get(
				"damage_buff_multiplier"
			)

			if damage_multiplier != null:
				raw_damage *= float(damage_multiplier)

		var is_critical: bool = character_stats.is_critical_hit()
		var final_damage: float = raw_damage

		if is_critical:
			final_damage *= character_stats.get_critical_damage_multiplier()

		var health_before_hit := maxf(float(target.get("health")), 0.0)
		var actual_damage := minf(final_damage, health_before_hit)
		target.take_damage(final_damage, is_critical)
		character_stats.apply_on_hit_effects(actual_damage)

		print("=== KNIGHT CAUSOU DANO ===")
		print("Dano: ", final_damage)
		print("Alvo: ", target.name)
	else:
		push_warning(
			"Knight: o alvo não possui o método take_damage()."
		)

	while is_instance_valid(animation_player):
		if not animation_player.is_playing():
			break

		if animation_player.current_animation != attack_animation:
			break

		await animation_player.animation_finished

	if my_attack_id != attack_id:
		return

	_finish_attack()


func _finish_attack() -> void:
	attacking = false
	current_attack_target = null
	current_animation = &""

	animation_player.speed_scale = animation_speed


func play_animation(animation_name: StringName) -> void:
	if current_animation == animation_name and animation_player.is_playing():
		return

	if not animation_player.has_animation(animation_name):
		if not warned_animations.has(animation_name):
			warned_animations[animation_name] = true
			push_warning(
				"Knight: animação não encontrada: " + str(animation_name)
			)
		return

	current_animation = animation_name

	if animation_name == attack_animation:
		animation_player.speed_scale = 2.0
	else:
		animation_player.speed_scale = animation_speed

	animation_player.play(animation_name, 0.2)


func look_at_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	var direction: Vector3 = target.global_position - global_position
	direction.y = 0.0

	if direction.length_squared() <= 0.001:
		return

	rotation.y = atan2(direction.x, direction.z)


func _on_attributes_changed() -> void:
	var old_max_health := max_health
	max_health = 150.0 + character_stats.get_max_health_bonus()
	if max_health > old_max_health:
		health += max_health - old_max_health
	health = clampf(health, 0.0, max_health)


func take_damage(damage: float, damage_type: String = "physical") -> void:
	if dead:
		return

	var final_damage: float = character_stats.calculate_damage_after_defense(damage, damage_type)
	health -= final_damage

	flash_hit()

	print(
		"Knight recebeu ",
		damage,
		" de dano. Vida: ",
		health,
		"/",
		max_health
	)

	show_damage(final_damage)

	if health <= 0:
		health = 0
		die()


func die() -> void:
	if dead:
		return

	dead = true

	print("=== KNIGHT MORREU ===")

	attacking = false
	action_locked = false
	is_running = false
	skill_animation_finished = false
	attack_animation_playing = false
	is_returning_to_initial_position = false

	attack_id += 1
	frenzy_active = false
	if is_instance_valid(frenzy_instance):
		frenzy_instance.queue_free()
		frenzy_instance = null

	animation_player.speed_scale = 1.0

	if animation_player.has_animation("knight/die"):
		animation_player.play("knight/die", 0.15)
		
	

func on_animation_finished(anim_name):
	if anim_name == "knight/die":
		# Não destruir o herói: a interface ainda precisa acessar seus
		# CharacterStats e permitir distribuir atributos/equipar itens.
		# Ele continua registrado, mas não participa mais do mundo/combat.
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED

		for collision_node in find_children("*", "CollisionShape3D", true, false):
			collision_node.set_deferred("disabled", true)

		for area_node in find_children("*", "Area3D", true, false):
			area_node.set_deferred("monitoring", false)
			area_node.set_deferred("monitorable", false)

func show_damage(damage: float) -> void:
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

	var start_position: Vector3 = global_position + Vector3(0, damage_height, 0)

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


func flash_hit() -> void:
	var meshes = find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)

	for i in range(2):
		for mesh in meshes:
			if not is_instance_valid(mesh):
				continue

			if mesh == level_up_effect or level_up_effect.is_ancestor_of(mesh):
				continue

			var material = mesh.get_active_material(0)

			if material == null:
				continue

			if material is ShaderMaterial:
				continue

			var flash_material = material.duplicate()

			flash_material.albedo_color = Color(1.0, 0.03, 0.03, 1.0)
			flash_material.emission_enabled = true
			flash_material.emission = Color(1.0, 0.0, 0.0, 1.0)
			flash_material.emission_energy_multiplier = 3.0

			mesh.material_override = flash_material

		await get_tree().create_timer(0.08).timeout

		for mesh in meshes:
			if not is_instance_valid(mesh):
				continue

			if mesh == level_up_effect or level_up_effect.is_ancestor_of(mesh):
				continue

			mesh.material_override = null

		await get_tree().create_timer(0.05).timeout


func start_running() -> void:
	attack_id += 1
	attacking = false
	action_locked = false
	attack_animation_playing = false
	skill_animation_finished = false
	basic_attack_lock = false
	current_attack_target = null
	current_animation = &""

	if dead:
		return

	is_returning_to_initial_position = false
	attack_timer = 0.0
	rotation.y = initial_rotation_y
	animation_player.speed_scale = animation_speed
	play_animation(running_animation)


func cancel_attack_on_target(target: Node3D) -> void:
	if dead:
		return

	if not is_instance_valid(target) or current_attack_target != target:
		return

	print("=== KNIGHT: ATAQUE CANCELADO === | ALVO: ", target.name)

	attack_id += 1
	attacking = false
	action_locked = false
	attack_animation_playing = false
	basic_attack_lock = false
	current_attack_target = null
	current_animation = &""

	if is_instance_valid(animation_player):
		animation_player.stop()
		animation_player.speed_scale = animation_speed

	

	if is_instance_valid(world_scroller) and world_scroller.running:
		play_animation(running_animation)
	else:
		play_animation(idle_animation)


func play_level_up_effect():

	if not is_instance_valid(level_up_effect):
		return

	level_up_effect.visible = true

	await get_tree().create_timer(2.0).timeout

	level_up_effect.visible = false
