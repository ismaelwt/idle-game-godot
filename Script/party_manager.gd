extends Node
class_name PartyManager

signal party_changed(heroes: Array[Node3D])

@export_range(1, 3, 1) var max_party_size: int = 3

var heroes: Array[Node3D] = []
var main_hero: Node3D = null
var companion_hero: Node3D = null

var _game_manager: Node = null


func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")

	if is_instance_valid(_game_manager):
		if _game_manager.has_signal("companion_state_changed"):
			if not _game_manager.companion_state_changed.is_connected(
				_on_companion_state_changed
			):
				_game_manager.companion_state_changed.connect(
					_on_companion_state_changed
				)

	call_deferred("_initialize_party")


func _initialize_party() -> void:
	var selected_id := "mage"
	if is_instance_valid(CharacterSelectionData):
		selected_id = CharacterSelectionData.get_selected_character_id()

	var candidates := _discover_heroes()
	main_hero = null
	companion_hero = null
	heroes.clear()

	for candidate in candidates:
		if _get_hero_id(candidate) == selected_id:
			main_hero = candidate
			break

	if not is_instance_valid(main_hero):
		push_error(
			"PartyManager: nenhum herói registrado corresponde ao ID principal '%s'."
			% selected_id
		)
		return

	for candidate in candidates:
		_set_hero_active(candidate, candidate == main_hero)

	register_hero(main_hero)
	_refresh_companion()

	print("=== EQUIPE ATUAL ===")
	print("ID principal: ", selected_id)
	print("Principal: ", main_hero.name)
	print(
		"Companheiro: ",
		companion_hero.name if is_instance_valid(companion_hero) else "nenhum"
	)
	print("Total de heróis: ", get_heroes().size())


func _discover_heroes() -> Array[Node3D]:
	var discovered: Array[Node3D] = []
	var candidates: Array[Node] = []

	for candidate in get_tree().get_nodes_in_group("party_heroes"):
		if candidate is Node3D and not candidates.has(candidate):
			candidates.append(candidate)

	# Compatibilidade com cenas atuais: heróis podem ainda não estar no grupo.
	# A descoberta é por CharacterStats/ID, nunca pelo nome do nó.
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		for candidate in parent_node.get_children():
			if not candidate is Node3D:
				continue
			if not _has_hero_identity(candidate):
				continue
			if not candidates.has(candidate):
				candidates.append(candidate)

	for candidate in candidates:
		if candidate is Node3D and _has_hero_identity(candidate):
			discovered.append(candidate)

	return discovered


func _has_hero_identity(hero: Node3D) -> bool:
	if not is_instance_valid(hero):
		return false

	if hero.has_meta("hero_id"):
		return not str(hero.get_meta("hero_id")).strip_edges().is_empty()

	var stats := hero.get_node_or_null("CharacterStats")
	if not is_instance_valid(stats):
		stats = hero.find_child("CharacterStats", true, false)

	if not is_instance_valid(stats):
		return false

	var hero_id := str(stats.get("hero_id")).strip_edges()
	var hero_class := str(stats.get("hero_class")).strip_edges()
	return not hero_id.is_empty() or not hero_class.is_empty()


func _get_hero_id(hero: Node3D) -> String:
	if not is_instance_valid(hero):
		return ""

	var raw_id := ""
	if hero.has_meta("hero_id"):
		raw_id = str(hero.get_meta("hero_id"))
	else:
		var stats := hero.get_node_or_null("CharacterStats")
		if not is_instance_valid(stats):
			stats = hero.find_child("CharacterStats", true, false)

		if is_instance_valid(stats):
			raw_id = str(stats.get("hero_id"))

	if raw_id.strip_edges().is_empty():
		return ""

	if is_instance_valid(CharacterSelectionData):
		return CharacterSelectionData.normalize_hero_id(raw_id)

	return raw_id.strip_edges().to_lower()


func _on_companion_state_changed() -> void:
	_refresh_companion()


func _refresh_companion() -> void:
	if not is_instance_valid(main_hero):
		return

	var active_id := ""
	if is_instance_valid(_game_manager):
		active_id = str(_game_manager.get("active_companion_id")).strip_edges().to_lower()

	var desired_companion: Node3D = null
	if (
		not active_id.is_empty()
		and is_instance_valid(_game_manager)
		and _game_manager.has_method("owns_companion")
		and bool(_game_manager.owns_companion(active_id))
	):
		for candidate in _discover_heroes():
			if candidate == main_hero:
				continue
			if _get_hero_id(candidate) == active_id:
				desired_companion = candidate
				break

	# Remove um companheiro anterior se ele foi desequipado/trocado.
	if is_instance_valid(companion_hero) and companion_hero != desired_companion:
		var previous_companion := companion_hero
		companion_hero = null
		_set_hero_active(previous_companion, false)
		unregister_hero(previous_companion)

	if not is_instance_valid(desired_companion):
		companion_hero = null
		return

	companion_hero = desired_companion
	_set_hero_active(companion_hero, true)
	register_hero(companion_hero)


func get_main_hero() -> Node3D:
	return main_hero if is_instance_valid(main_hero) else null


# Retorna um herói vivo para sistemas que precisam de uma referência espacial
# ou de gameplay, sem mudar a identidade do herói principal escolhido.
func get_alive_reference_hero() -> Node3D:
	if _is_hero_alive(main_hero):
		return main_hero

	if _is_hero_alive(companion_hero):
		return companion_hero

	for hero in get_alive_heroes():
		if _is_hero_alive(hero):
			return hero

	return null


func _is_hero_alive(hero: Variant) -> bool:
	if not is_instance_valid(hero) or not hero is Node3D:
		return false

	var dead_value = hero.get("dead")
	return dead_value == null or not bool(dead_value)


func get_companion_hero() -> Node3D:
	return companion_hero if is_instance_valid(companion_hero) else null


func _set_hero_active(hero: Node3D, active: bool) -> void:
	if not is_instance_valid(hero):
		return

	hero.visible = active
	hero.process_mode = Node.PROCESS_MODE_INHERIT
	hero.set_process(active)
	hero.set_physics_process(active)


func register_hero(hero: Node3D) -> bool:
	if not is_instance_valid(hero):
		return false

	if heroes.has(hero):
		return true

	if heroes.size() >= max_party_size:
		push_warning("PartyManager: limite de heróis atingido.")
		return false

	heroes.append(hero)
	party_changed.emit(get_heroes())
	print("PartyManager: herói registrado: ", hero.name)
	return true


func unregister_hero(hero: Node3D) -> void:
	if heroes.has(hero):
		heroes.erase(hero)
		party_changed.emit(get_heroes())


func get_heroes() -> Array[Node3D]:
	var valid_heroes: Array[Node3D] = []
	for hero in heroes:
		if is_instance_valid(hero):
			valid_heroes.append(hero)
	return valid_heroes


func get_alive_heroes() -> Array[Node3D]:
	var alive_heroes: Array[Node3D] = []
	for hero in get_heroes():
		var dead_value = hero.get("dead")
		if dead_value == null or not bool(dead_value):
			alive_heroes.append(hero)
	return alive_heroes


func set_hero_target(hero: Node3D, target: Node3D) -> bool:
	if not is_instance_valid(hero) or not heroes.has(hero):
		return false

	if is_instance_valid(target):
		hero.set_meta("combat_target", target)
	else:
		hero.remove_meta("combat_target")
	return true


func get_hero_target(hero: Node3D) -> Node3D:
	if not is_instance_valid(hero):
		return null
	if not hero.has_meta("combat_target"):
		return null

	var target = hero.get_meta("combat_target")
	if not is_instance_valid(target):
		hero.remove_meta("combat_target")
		return null
	return target as Node3D


func grant_enemy_rewards(xp_reward: int, gold_reward: int) -> void:
	# Ouro continua compartilhado entre todos os heróis.
	if gold_reward > 0:
		var game_manager := get_node_or_null("/root/GameManager")
		if is_instance_valid(game_manager) and game_manager.has_method("add_gold"):
			game_manager.add_gold(gold_reward)
			print("Ouro recebido: ", gold_reward)
		else:
			push_warning("PartyManager: GameManager não encontrado ou sem add_gold().")

	var alive_heroes := get_alive_heroes()
	if alive_heroes.is_empty():
		print("PartyManager: nenhum herói vivo para receber XP.")
		return

	var save_manager := get_node_or_null("/root/SaveManager")
	for hero in alive_heroes:
		if not is_instance_valid(hero):
			continue

		var stats := hero.get_node_or_null("CharacterStats")
		if not is_instance_valid(stats):
			stats = hero.find_child("CharacterStats", true, false)

		if not is_instance_valid(stats):
			push_warning("PartyManager: CharacterStats não encontrado em %s." % hero.name)
			continue

		if stats.has_method("add_xp"):
			stats.add_xp(xp_reward)
			print("XP recebido | Herói: ", hero.name, " | XP: ", xp_reward)

		if is_instance_valid(save_manager) and save_manager.has_method("save_character"):
			var hero_id := str(stats.get("hero_id"))
			if hero_id.is_empty():
				hero_id = _get_hero_id(hero)
			save_manager.save_character(stats, null, hero_id)
		else:
			push_warning("PartyManager: SaveManager não encontrado ou sem save_character().")
