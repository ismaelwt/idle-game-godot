extends Node
class_name PartyManager

signal party_changed(heroes: Array[Node3D])

@export_range(1, 3, 1) var max_party_size: int = 3

const KNIGHT_COMPANION_ID: String = "knight"

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
		selected_id = str(
			CharacterSelectionData.selected_character
		).to_lower()

	var selected_node_name := (
		"Knight" if selected_id == "knight" else "Player"
	)

	var other_node_name := (
		"Player" if selected_node_name == "Knight" else "Knight"
	)

	var all_party_heroes := get_tree().get_nodes_in_group(
		"party_heroes"
	)

	# Localiza os dois personagens mesmo que não estejam no grupo.
	var parent_node := get_parent()

	for hero_name in ["Player", "Knight"]:
		var candidate := parent_node.get_node_or_null(hero_name)

		if candidate is Node3D and not all_party_heroes.has(candidate):
			all_party_heroes.append(candidate)

	main_hero = null
	companion_hero = null
	heroes.clear()

	for candidate in all_party_heroes:
		if not candidate is Node3D:
			continue

		if candidate.name == selected_node_name:
			main_hero = candidate

	# O outro personagem só será companheiro se for o Knight comprado
	# e equipado, e o personagem principal for o Mage.
	var other_hero: Node3D = null

	for candidate in all_party_heroes:
		if candidate is Node3D and candidate.name == other_node_name:
			other_hero = candidate
			break

	if is_instance_valid(main_hero):
		_set_hero_active(main_hero, true)
		register_hero(main_hero)
	else:
		push_error(
			"PartyManager: personagem principal '%s' não encontrado."
			% selected_node_name
		)

	# Primeiro oculta o personagem não selecionado.
	if is_instance_valid(other_hero):
		_set_hero_active(other_hero, false)

	# Depois verifica se o Knight deve aparecer como companheiro.
	_refresh_companion()

	print("=== EQUIPE ATUAL ===")
	print("Personagem selecionado: ", selected_id)
	print(
		"Principal: ",
		main_hero.name if is_instance_valid(main_hero) else "nenhum"
	)
	print(
		"Companheiro: ",
		companion_hero.name if is_instance_valid(companion_hero) else "nenhum"
	)
	print("Total de heróis: ", get_heroes().size())


func _on_companion_state_changed() -> void:
	_refresh_companion()


func _refresh_companion() -> void:
	if not is_instance_valid(main_hero):
		return

	# O Knight não pode ser companheiro de si próprio.
	if main_hero.name == "Knight":
		_remove_companion()
		return

	var knight := get_parent().get_node_or_null("Knight") as Node3D

	if not is_instance_valid(knight):
		push_warning("PartyManager: nó Knight não encontrado na cena.")
		_remove_companion()
		return

	var active_id := ""

	if is_instance_valid(_game_manager):
		active_id = str(
			_game_manager.get("active_companion_id")
		).to_lower()

	var is_equipped: bool = (
		active_id == KNIGHT_COMPANION_ID
		and is_instance_valid(_game_manager)
		and _game_manager.has_method("owns_companion")
		and bool(_game_manager.owns_companion(KNIGHT_COMPANION_ID))
	)

	if is_equipped:
		companion_hero = knight

		# Torna o Knight visível e permite que seu script processe.
		_set_hero_active(companion_hero, true)

		if not heroes.has(companion_hero):
			register_hero(companion_hero)

		print("Companheiro Knight ativado e visível.")
	else:
		_remove_companion()


func _remove_companion() -> void:
	if not is_instance_valid(companion_hero):
		companion_hero = null
		return

	var old_companion := companion_hero

	if old_companion != main_hero:
		_set_hero_active(old_companion, false)
		unregister_hero(old_companion)

	companion_hero = null

	print("Nenhum companheiro equipado.")


func get_main_hero() -> Node3D:
	return main_hero if is_instance_valid(main_hero) else null


func get_companion_hero() -> Node3D:
	return companion_hero if is_instance_valid(companion_hero) else null


func _set_hero_active(hero: Node3D, active: bool) -> void:
	if not is_instance_valid(hero):
		return

	hero.visible = active
	hero.process_mode = Node.PROCESS_MODE_INHERIT
	hero.set_process(active)
	hero.set_physics_process(active)


func _set_collision_state_recursive(node: Node, active: bool) -> void:
	if node is CollisionObject3D and not active:
		node.set("collision_layer", 0)
		node.set("collision_mask", 0)

	if node is CollisionShape3D or node is CollisionPolygon3D:
		node.set("disabled", not active)

	for child in node.get_children():
		_set_collision_state_recursive(child, active)


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
		if hero.get("dead") == null or not bool(hero.get("dead")):
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
	# Ouro compartilhado.
	if gold_reward > 0:
		var game_manager := get_node_or_null("/root/GameManager")

		if (
			is_instance_valid(game_manager)
			and game_manager.has_method("add_gold")
		):
			game_manager.add_gold(gold_reward)
			print("Ouro recebido: ", gold_reward)
		else:
			push_warning(
				"PartyManager: GameManager não encontrado ou sem add_gold()."
			)

	# Somente os heróis vivos e registrados recebem XP.
	var alive_heroes := get_alive_heroes()

	if alive_heroes.is_empty():
		print("PartyManager: nenhum herói vivo para receber XP.")
		return

	var save_manager := get_node_or_null("/root/SaveManager")
	var player := get_tree().get_first_node_in_group("player")

	for hero in alive_heroes:
		if not is_instance_valid(hero):
			continue

		var stats = hero.get("character_stats")

		if stats == null or not is_instance_valid(stats):
			push_warning(
				"PartyManager: CharacterStats não encontrado em %s."
				% hero.name
			)
			continue

		if stats.has_method("add_xp"):
			stats.add_xp(xp_reward)

			print(
				"XP recebido | Herói: ",
				hero.name,
				" | XP: ",
				xp_reward
			)

		if (
			is_instance_valid(save_manager)
			and save_manager.has_method("save_character")
		):
			var hero_id := ""

			if hero == player:
				hero_id = "player"
			elif hero.has_meta("hero_id"):
				hero_id = str(hero.get_meta("hero_id"))
			elif stats.get("hero_id") != null:
				hero_id = str(stats.get("hero_id"))
			else:
				hero_id = str(hero.name)

			save_manager.save_character(stats, null, hero_id)
		else:
			push_warning(
				"PartyManager: SaveManager não encontrado ou sem save_character()."
			)
