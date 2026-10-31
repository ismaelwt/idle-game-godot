
extends Node
class_name CombatController

signal combat_cycle_started
signal combat_cycle_finished

@export_category("Targeting")
@export_range(0.1, 2.0, 0.1) var target_refresh_interval: float = 0.5

@export_category("Skill Rotation")
@export var enable_skill_rotation: bool = true

var party_manager: PartyManager = null
var enemy_spawner: Node = null
var combat_active: bool = false

var target_refresh_timer: float = 0.0

# Cada herói possui sua própria rotação e seus próprios cooldowns.
# A chave do dicionário é hero.get_instance_id().
var hero_skill_states: Dictionary = {}


func setup(manager: PartyManager) -> void:
	party_manager = manager


func _ready() -> void:
	var manager := get_parent().get_node_or_null("PartyManager") as PartyManager

	if manager == null:
		push_warning("CombatController: PartyManager não encontrado.")
		return

	setup(manager)

	enemy_spawner = get_parent().get_node_or_null("EnemySpawner")

	if enemy_spawner == null:
		push_warning("CombatController: EnemySpawner não encontrado.")
		return

	print("=== COMBAT CONTROLLER CONECTADO ===")
	print("Heróis recebidos: ", get_heroes().map(func(hero): return hero.name))
	initialize_hero_skill_states()


func _process(delta: float) -> void:
	if not combat_active:
		return
	
	update_skill_cooldowns(delta)

	target_refresh_timer -= delta

	if target_refresh_timer > 0.0:
		return

	target_refresh_timer = target_refresh_interval
	refresh_hero_targets()


func start_combat() -> void:
	if not is_instance_valid(party_manager):
		push_warning("CombatController: PartyManager não configurado.")
		return

	if combat_active:
		return

	combat_active = true
	target_refresh_timer = 0.0
	combat_cycle_started.emit()

	print("CombatController: combate iniciado.")
	print("Heróis ativos: ", party_manager.get_alive_heroes().size())

	refresh_hero_targets()


func stop_combat() -> void:
	if not combat_active:
		return

	combat_active = false
	combat_cycle_finished.emit()

	print("CombatController: combate encerrado.")


# =========================================================
# HERÓIS
# =========================================================

func get_heroes() -> Array[Node3D]:
	if not is_instance_valid(party_manager):
		return []

	return party_manager.get_alive_heroes()


func set_target(hero: Node3D, target: Node3D) -> bool:
	if not combat_active:
		return false

	if not is_instance_valid(party_manager):
		return false

	return party_manager.set_hero_target(hero, target)


func get_target(hero: Node3D) -> Node3D:
	if not is_instance_valid(party_manager):
		return null

	return party_manager.get_hero_target(hero)


func get_valid_target_for_hero(hero: Node3D) -> Node3D:
	var target: Node3D = get_target(hero)

	if not is_instance_valid(target):
		return null

	if not is_enemy_alive(target):
		return null

	return target


func find_target_for_hero(hero: Node3D) -> Node3D:
	if not is_instance_valid(hero):
		return null

	if not is_instance_valid(enemy_spawner):
		return null

	var attack_range_value = hero.get("attack_range")

	if attack_range_value == null:
		push_warning(
			"CombatController: herói sem attack_range: " + hero.name
		)
		return null

	var attack_range: float = float(attack_range_value)
	var closest_enemy: Node3D = null
	var closest_distance: float = INF

	for enemy in enemy_spawner.enemies:
		if not is_instance_valid(enemy):
			continue

		if not is_enemy_alive(enemy):
			continue

		var distance: float = hero.global_position.distance_to(
			enemy.global_position
		)

		if distance > attack_range + 0.01:
			continue

		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	return closest_enemy


func refresh_hero_targets() -> void:
	if not combat_active or not is_instance_valid(party_manager):
		return

	for hero in party_manager.get_alive_heroes():
		var current_target: Node3D = get_valid_target_for_hero(hero)

		# Mantém o alvo atual enquanto ele estiver vivo.
		if is_instance_valid(current_target):
			continue

		var new_target: Node3D = find_target_for_hero(hero)

		if is_instance_valid(new_target):
			set_target(hero, new_target)

			print(
				"[ALVO ATUALIZADO] ",
				hero.name,
				" -> ",
				new_target.name
			)
		else:
			set_target(hero, null)


func on_enemy_died(dead_enemy: Node3D) -> void:
	if not is_instance_valid(party_manager):
		return

	for hero in party_manager.get_alive_heroes():
		var current_target: Node3D = get_target(hero)

		if current_target == dead_enemy:
			set_target(hero, null)

	refresh_hero_targets()


func is_enemy_alive(enemy: Node3D) -> bool:
	if not is_instance_valid(enemy):
		return false

	if enemy.get("dying") == true:
		return false

	var health_value = enemy.get("health")

	if health_value != null and float(health_value) <= 0.0:
		return false

	return true


# =========================================================
# ROTAÇÃO INDIVIDUAL DE HABILIDADES
# =========================================================

func prepare_skills(hero: Node3D) -> void:
	if not is_instance_valid(hero):
		return

	var stats = hero.get("character_stats")

	if not is_instance_valid(stats):
		push_warning(
			"CombatController: CharacterStats não encontrado em "
			+ hero.name
		)
		return

	var hero_id: int = hero.get_instance_id()
	var current_order: Array = stats.get("skill_order").duplicate()

	# Preserva os cooldowns se a ordem das habilidades não mudou.
	if hero_skill_states.has(hero_id):
		var existing_state: Dictionary = hero_skill_states[hero_id]
		var previous_order: Array = existing_state.get(
			"last_skill_order", []
		)

		if current_order == previous_order:
			return

	# Se a ordem mudou, reconstrói a rotação desse herói.
	# Os cooldowns antigos desse herói são reiniciados.
	var skill_ids: Array[String] = []
	var skill_scenes: Array[PackedScene] = []
	var skill_mana_costs: Array[float] = []
	var skill_cooldowns: Array[float] = []
	var skill_timers: Array[float] = []
	var skill_available: Array[bool] = []

	for skill_value in current_order:
		var skill_id: String = str(skill_value)

		if not stats.has_skill(skill_id):
			continue

		if not SkillTree.has_skill(skill_id):
			continue

		var skill_data: Dictionary = SkillTree.get_skill(skill_id)

		if not skill_data.has("scene"):
			continue

		var skill_scene = skill_data["scene"]

		if not skill_scene is PackedScene:
			continue

		var skill_instance = skill_scene.instantiate()

		var mana_cost: float = float(
			skill_instance.get("mana_cost")
		)

		var cooldown: float = float(
			skill_instance.get("cooldown")
		)

		skill_instance.free()

		skill_ids.append(skill_id)
		skill_scenes.append(skill_scene)
		skill_mana_costs.append(mana_cost)
		skill_cooldowns.append(cooldown)
		skill_timers.append(0.0)
		skill_available.append(true)

	var state: Dictionary = {
		"hero_id": hero_id,
		"hero_name": hero.name,
		"skill_ids": skill_ids,
		"skill_scenes": skill_scenes,
		"skill_mana_costs": skill_mana_costs,
		"skill_cooldowns": skill_cooldowns,
		"skill_timers": skill_timers,
		"skill_available": skill_available,
		"skill_count": skill_ids.size(),
		"next_skill_index": 0,
		"last_skill_order": current_order.duplicate(),
		"active_skill_order": current_order.duplicate()
	}

	hero_skill_states[hero_id] = state

	print(
		"=== ROTAÇÃO PREPARADA: ",
		hero.name,
		" ==="
	)
	print("Ordem: ", current_order)
	print("Skills válidas: ", skill_ids)


func update_skill_cooldowns(delta: float) -> void:
	# Atualiza separadamente os cooldowns de cada herói.
	for hero_id in hero_skill_states.keys():
		var state: Dictionary = hero_skill_states[hero_id]

		var skill_ids: Array = state.get("skill_ids", [])
		var skill_timers: Array = state.get("skill_timers", [])
		var skill_available: Array = state.get(
			"skill_available", []
		)

		var skill_count: int = mini(
			skill_timers.size(),
			skill_available.size()
		)

		for i in range(skill_count):
			if skill_available[i]:
				continue

			skill_timers[i] = maxf(
				float(skill_timers[i]) - delta,
				0.0
			)

			if skill_timers[i] <= 0.0:
				skill_available[i] = true

				print(
					"SKILL DISPONÍVEL: ",
					skill_ids[i],
					" | HERÓI: ",
					state.get("hero_name", "Desconhecido")
				)

		state["skill_timers"] = skill_timers
		state["skill_available"] = skill_available

		hero_skill_states[hero_id] = state


func process_skill_rotation(
	hero: Node3D,
	target: Node3D
) -> void:
	if not enable_skill_rotation:
		return

	if not combat_active:
		return

	if not is_instance_valid(hero) or bool(hero.get("dead")):
		return

	if not is_instance_valid(target) or not is_enemy_alive(target):
		return

	if bool(hero.get("attacking")):
		return

	var stats = hero.get("character_stats")

	if not is_instance_valid(stats):
		return

	var hero_id: int = hero.get_instance_id()
	var current_order: Array = stats.get("skill_order")

	# Garante que cada herói tenha seu próprio estado.
	if not hero_skill_states.has(hero_id):
		prepare_skills(hero)

	if not hero_skill_states.has(hero_id):
		return

	var state: Dictionary = hero_skill_states[hero_id]
	var last_order: Array = state.get("last_skill_order", [])

	# Atualiza a rotação apenas se a ordem desse herói mudou.
	if current_order != last_order:
		prepare_skills(hero)

		if not hero_skill_states.has(hero_id):
			return

		state = hero_skill_states[hero_id]

	var skill_ids: Array = state.get("skill_ids", [])
	var _skill_scenes: Array = state.get("skill_scenes", [])
	var mana_costs: Array = state.get("skill_mana_costs", [])
	var cooldowns: Array = state.get("skill_cooldowns", [])
	var timers: Array = state.get("skill_timers", [])
	var available: Array = state.get("skill_available", [])

	var skill_count: int = skill_ids.size()

	if skill_count == 0:
		if is_enemy_alive(target) and hero.has_method("basic_attack"):
			hero.call("basic_attack", target)
		return

	var next_index: int = int(state.get("next_skill_index", 0))
	next_index = posmod(next_index, skill_count)

	# Procura a próxima habilidade disponível deste herói.
	for attempt in range(skill_count):
		var index: int = (next_index + attempt) % skill_count
		var skill_id: String = str(skill_ids[index])

		if not current_order.has(skill_id):
			continue

		if not available[index]:
			continue

		if not is_enemy_alive(target):
			return

		var mana_cost: float = float(mana_costs[index])

		if float(stats.get("mana")) < mana_cost:
			continue

		# Reserva o próximo índice e inicia o cooldown individual.
		state["next_skill_index"] = (index + 1) % skill_count

		timers[index] = float(cooldowns[index])
		available[index] = false

		state["skill_timers"] = timers
		state["skill_available"] = available

		hero_skill_states[hero_id] = state

		stats.use_mana(mana_cost)

		print(
			"USANDO SKILL: ", skill_id,
			" | HERÓI: ", hero.name,
			" | MANA: ", mana_cost,
			" | COOLDOWN: ", cooldowns[index], "s"
		)

		if hero.has_method("use_skill"):
			hero.call("use_skill", skill_id, target)

		return

	# Mantém o comportamento anterior:
	# se alguma habilidade estiver pronta e houver mana,
	# aguarda em vez de antecipar o ataque básico.
	for i in range(skill_count):
		if not current_order.has(skill_ids[i]):
			continue

		if available[i] and float(stats.get("mana")) >= float(mana_costs[i]):
			return
	
		if not is_enemy_alive(target):
			return

		if not can_attempt_basic_attack(hero, target):
			return

	if hero.has_method("basic_attack"):
		print(
			"=== COMBAT CONTROLLER -> BASIC ATTACK ===",
			" | HERÓI: ", hero.name,
			" | ALVO: ", target.name
		)

		hero.call("basic_attack", target)




func initialize_hero_skill_states() -> void:
	if not is_instance_valid(party_manager):
		return

	for hero in party_manager.get_heroes():
		if not is_instance_valid(hero):
			continue

		var hero_id: int = hero.get_instance_id()

		if not hero_skill_states.has(hero_id):
			prepare_skills(hero)

func can_attempt_basic_attack(hero: Node3D, target: Node3D) -> bool:
	if not is_instance_valid(hero):
		return false

	if not is_instance_valid(target):
		return false

	if bool(hero.get("dead")):
		return false

	if bool(hero.get("attacking")):
		return false

	var action_locked_value = hero.get("action_locked")
	if action_locked_value != null and bool(action_locked_value):
		return false

	var attack_timer_value = hero.get("attack_timer")
	if attack_timer_value != null and float(attack_timer_value) > 0.0:
		return false

	# Só aplica esta validação aos heróis que definem melee_range.
	var melee_range_value = hero.get("melee_range")

	if melee_range_value != null:
		var hero_position := Vector2(
			hero.global_position.x,
			hero.global_position.z
		)

		var target_position := Vector2(
			target.global_position.x,
			target.global_position.z
		)

		var distance := hero_position.distance_to(target_position)

		if distance > float(melee_range_value) + 0.01:
			return false

	return is_enemy_alive(target)
