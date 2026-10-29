extends Node3D

@export_category("Boss")
@export var boss_scene: PackedScene

@export_category("Wave Configuration")
@export var current_wave: int = 1
@export_subgroup("Wave 1")
@export var wave_1_slots: Array[EnemySpawnSlot] = []
@export_subgroup("Wave 2")
@export var wave_2_slots: Array[EnemySpawnSlot] = []
@export_subgroup("Wave 3")
@export var wave_3_slots: Array[EnemySpawnSlot] = []

@export_category("Spawn")
@export var spawn_distance: float = 20.0
@export var spawn_spacing: float = 5.0
@export var x_spacing: float = 4.0
@export var spawn_radius: float = 8.0
@export var min_enemy_spacing: float = 3.0
@export var max_spawn_attempts: int = 30

@export_category("Level Scaling")
@export var min_level_offset: int = 0
@export var max_level_offset: int = 2
@export var max_enemy_level_limit: int = 5

@onready var level_root: Node = get_parent()
@onready var selected_hero: Node3D =  _get_selected_hero()
@onready var party_manager: PartyManager = get_parent().get_node_or_null("PartyManager") as PartyManager
@onready var level_controller: Node = get_parent().get_node("LevelController")
@onready var world_scroller: Node3D = get_parent().get_node("World/WorldScroller")

var enemies: Array[Node3D] = []
var wave_transition_in_progress: bool = false


func _ready() -> void:
	await get_tree().process_frame
	print("=== ENEMY SPAWNER READY === | Onda: ", current_wave)
	spawn_enemies()


func _process(_delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]):
			enemies.remove_at(i)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if bool(enemy.get("dying")):
			continue
		if not is_instance_valid(selected_hero):
			continue

		var distance: float = enemy.global_position.distance_to(selected_hero.global_position)

		if distance <= float(selected_hero.get("attack_range")):
			level_controller.start_combat(enemy)

		if not bool(enemy.get("in_combat")):
			if distance <= float(enemy.get("attack_range")):
				enemy.start_combat()


func spawn_enemies() -> void:
	var selected_slots: Array[EnemySpawnSlot] = []

	match current_wave:
		1:
			selected_slots = wave_1_slots
		2:
			selected_slots = wave_2_slots
		3:
			selected_slots = wave_3_slots
		_:
			push_warning("Sem slots de inimigos para a onda %d." % current_wave)
			return

	var spawn_list: Array[Dictionary] = []
	for slot in selected_slots:
		if slot == null or slot.enemy_scene == null or slot.amount <= 0:
			continue
		spawn_list.append({"scene": slot.enemy_scene, "amount": slot.amount})

	var total_enemies: int = 0
	for entry in spawn_list:
		total_enemies += int(entry["amount"])

	if total_enemies <= 0:
		push_warning("Nenhum inimigo configurado na onda %d." % current_wave)
		return

	var spawn_center: Vector3 = selected_hero.global_position
	spawn_center.z += spawn_distance

	for entry in spawn_list:
		var scene: PackedScene = entry["scene"]
		var amount: int = int(entry["amount"])

		for _i in range(amount):
			var enemy := scene.instantiate() as Node3D
			if enemy == null:
				push_warning("Uma cena configurada não possui raiz Node3D.")
				continue

			if _has_property(enemy, "fallback_hero_target"):
				enemy.set("fallback_hero_target", selected_hero)

			var player_level: int = 1
			if is_instance_valid(selected_hero.get("character_stats")):
				player_level = maxi(1, int(selected_hero.character_stats.level))

			var min_enemy_level: int = mini(
				max_enemy_level_limit,
				maxi(1, player_level + min_level_offset)
			)
			var max_enemy_level: int = mini(
				max_enemy_level_limit,
				maxi(min_enemy_level, player_level + max_level_offset)
			)
			var selected_level: int = randi_range(min_enemy_level, max_enemy_level)

			if enemy.has_method("setup_level"):
				enemy.setup_level(selected_level)

			var spawn_position: Vector3 = get_valid_spawn_position(spawn_center)

			# WorldScroller continua sendo apenas o container espacial dos inimigos.
			# O controle de running/pausa pertence ao LevelController.
			world_scroller.add_child(enemy)
			enemy.global_position = spawn_position
			enemies.append(enemy)

	print(
		"=== INIMIGOS SPAWNADOS === | Onda: ", current_wave,
		" | Total configurado: ", total_enemies,
		" | Slots ativos: ", spawn_list.size(),
		" | Raio: ", spawn_radius
	)

	# Guarda a posição inicial desta onda no LevelController.
	if is_instance_valid(level_controller) and level_controller.has_method("mark_wave_start_positions"):
		level_controller.mark_wave_start_positions()


func advance_wave() -> void:
	if wave_transition_in_progress:
		return
	wave_transition_in_progress = true

	print("=== ONDA ", current_wave, " CONCLUÍDA ===")

	# O LevelController coordena a pausa do cenário e o avanço da formação.
	if is_instance_valid(level_controller):
		if level_controller.has_method("prepare_next_wave_transition"):
			await level_controller.prepare_next_wave_transition()
		else:
			push_warning(
				"LevelController não possui prepare_next_wave_transition(). "
				+ "Adicione o método ao LevelController antes de usar esta versão."
			)
			wave_transition_in_progress = false
			return

	if not is_instance_valid(level_controller):
		wave_transition_in_progress = false
		return

	if level_controller.is_party_defeated():
		wave_transition_in_progress = false
		return

	await get_tree().create_timer(1.0).timeout

	if not is_instance_valid(level_controller) or level_controller.is_party_defeated():
		wave_transition_in_progress = false
		return

	current_wave += 1
	level_controller.combat_enemies.clear()
	level_controller.current_enemy = null

	print("=== PRÓXIMA ONDA: ", current_wave, " ===")

	if current_wave >= 4:
		print("=== BOSS INCOMING ===")

		# Retoma a corrida antes de exibir o aviso.
		if level_controller.has_method("resume_after_wave_transition"):
			level_controller.resume_after_wave_transition()

		# O aviso acontece enquanto os heróis correm.
		level_controller.show_warning("WARNING!!!")

		if not is_instance_valid(level_controller) or level_controller.is_party_defeated():
			wave_transition_in_progress = false
			return

		spawn_boss()
		level_controller.state = 1
		print("=== RUNNING | BOSS SPAWN SOLICITADO ===")
	else:
		match current_wave:
			2:
				level_controller.show_warning("SECOND WAVE!!")
			3:
				level_controller.show_warning("THIRD WAVE!!")

		spawn_enemies()
		level_controller.state = 1
		print("=== RUNNING | ONDA ", current_wave, " ===")

	# A retomada do cenário é responsabilidade exclusiva do LevelController.
	if level_controller.has_method("resume_after_wave_transition"):
		level_controller.resume_after_wave_transition()

	wave_transition_in_progress = false


func spawn_boss() -> void:
	if boss_scene == null:
		push_error("EnemySpawner: nenhuma cena de Boss foi definida no Inspector.")
		return

	var boss := boss_scene.instantiate() as Node3D
	if boss == null:
		push_error("EnemySpawner: a cena do Boss precisa ter uma raiz Node3D.")
		return

	if _has_property(boss, "fallback_hero_target"):
		boss.set("fallback_hero_target", selected_hero)

	var player_level: int = 1
	if is_instance_valid(selected_hero) and is_instance_valid(selected_hero.get("character_stats")):
		player_level = maxi(1, int(selected_hero.character_stats.level))

	var selected_level: int = mini(player_level, max_enemy_level_limit)
	if boss.has_method("setup_level"):
		boss.setup_level(selected_level)

	world_scroller.add_child(boss)
	boss.global_position = selected_hero.global_position
	boss.global_position.z += spawn_distance

	if not enemies.has(boss):
		enemies.append(boss)

	print(
		"=== BOSS SPAWNADO === | Nível do jogador: ", player_level,
		" | Nível do boss: ", selected_level,
		" | Posição: ", boss.global_position
	)

	if is_instance_valid(level_controller) and level_controller.has_method("mark_wave_start_positions"):
		level_controller.mark_wave_start_positions()


func get_valid_spawn_position(spawn_center: Vector3) -> Vector3:
	for _attempt in range(max_spawn_attempts):
		var angle: float = randf_range(0.0, TAU)
		var distance: float = sqrt(randf()) * spawn_radius
		var candidate: Vector3 = spawn_center + Vector3(
			cos(angle) * distance,
			0.0,
			sin(angle) * distance
		)

		var valid: bool = true
		for enemy in enemies:
			if not is_instance_valid(enemy) or bool(enemy.get("dying")):
				continue

			var enemy_pos: Vector3 = enemy.global_position
			enemy_pos.y = candidate.y
			if enemy_pos.distance_to(candidate) < min_enemy_spacing:
				valid = false
				break

		if valid:
			return candidate

	var fallback_angle: float = randf_range(0.0, TAU)
	var fallback_distance: float = sqrt(randf()) * spawn_radius
	return spawn_center + Vector3(
		cos(fallback_angle) * fallback_distance,
		0.0,
		sin(fallback_angle) * fallback_distance
	)


func _has_property(object: Object, property_name: String) -> bool:
	if not is_instance_valid(object):
		return false
	for property_info in object.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false

func _get_selected_hero() -> Node3D:
	var selected_id := CharacterSelectionData.get_selected_character_id()
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return null

	var manager := parent_node.get_node_or_null("PartyManager") as PartyManager
	if is_instance_valid(manager):
		var main_hero := manager.get_main_hero()
		if is_instance_valid(main_hero):
			return main_hero

	for candidate in parent_node.get_children():
		if not candidate is Node3D:
			continue
		var stats = candidate.get("character_stats")
		if not is_instance_valid(stats):
			stats = candidate.get_node_or_null("CharacterStats")
		if not is_instance_valid(stats):
			stats = candidate.find_child("CharacterStats", true, false)
		if is_instance_valid(stats):
			var hero_id := CharacterSelectionData.normalize_hero_id(str(stats.get("hero_id")))
			if hero_id == selected_id:
				return candidate

	return null
