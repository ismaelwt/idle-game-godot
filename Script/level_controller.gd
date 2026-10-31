
extends Node



const CharacterSelectionDataScript = preload("res://Script/character_selection_data.gd")
enum State {
	PREPARING,
	RUNNING,
	COMBAT,
	REWARD,
	VICTORY,
	DEFEAT
}


var state: State = State.PREPARING
var paused: bool = false

var current_enemy: Node3D
var combat_enemies: Array[Node3D] = []

const DAMAGE_FONT: Font = preload("res://Fonts/Pix32.ttf")

var wave_start_positions: Dictionary = {}
var wave_start_position_recorded: bool = false

# A onda atual e sua configuração agora pertencem ao EnemySpawner.
var current_wave: int:
	get:
		if is_instance_valid(enemy_spawner):
			return enemy_spawner.current_wave
		return 1


@export_category("Automatic Retry")
var automatic_retry: bool = false


@onready var combat_controller = get_parent().get_node_or_null("CombatController")
@onready var party_manager = get_parent().get_node_or_null("PartyManager") as PartyManager
# Referência de compatibilidade para o herói principal; a equipe é descoberta por ID.
@onready var main_hero: Node3D = _get_selected_hero()


func _get_selected_hero() -> Node3D:
	var selected_id := "mage"
	if is_instance_valid(CharacterSelectionData):
		selected_id = CharacterSelectionData.get_selected_character_id()

	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return null

	for candidate in parent_node.get_children():
		if not candidate is Node3D:
			continue

		var stats := candidate.get_node_or_null("CharacterStats")
		if not is_instance_valid(stats):
			stats = candidate.find_child("CharacterStats", true, false)
		if not is_instance_valid(stats):
			continue

		var candidate_id := str(stats.get("hero_id"))
		if is_instance_valid(CharacterSelectionData):
			candidate_id = CharacterSelectionDataScript.normalize_hero_id(candidate_id)
		else:
			candidate_id = candidate_id.to_lower()

		if candidate_id == selected_id:
			return candidate

	return null
@onready var world_scroller = get_parent().get_node("World/WorldScroller")
@onready var enemy_spawner = get_parent().get_node("EnemySpawner")
@onready var inventory = get_parent().get_node("Inventory")


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	await get_tree().process_frame

	automatic_retry = SaveManager.load_auto_retry()

	start_running()

	await get_tree().create_timer(1.0).timeout

	if is_instance_valid(enemy_spawner) and enemy_spawner.current_wave == 1:
		show_warning("FIRST WAVE!!")


func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

		return

	if get_tree().paused:
		return

	if is_party_defeated():
		if state != State.DEFEAT:
			state = State.DEFEAT
			world_scroller.running = false

			print("=== DEFEAT ===")
			print("=== JOGO PARADO: TODOS OS HERÓIS FORAM DERROTADOS ===")

			if SaveManager.automatic_retry:
				await get_tree().create_timer(3.0).timeout

				var current_scene = get_tree().current_scene

				if is_instance_valid(current_scene):
					SceneLoader.change_scene(
						current_scene.scene_file_path
					)

				return

		return


	if state != State.COMBAT:
		return

	process_skills()


func is_party_defeated() -> bool:
	if is_instance_valid(party_manager):
		return party_manager.get_alive_heroes().is_empty()

	# Compatibilidade com cenas antigas sem PartyManager.
	return not is_instance_valid(main_hero) or bool(main_hero.get("dead"))


# Sistemas de câmera, spawn e salvamento precisam de um herói vivo,
# não necessariamente do herói principal que morreu.
func _get_alive_reference_hero() -> Node3D:
	if is_instance_valid(party_manager):
		var reference_hero := party_manager.get_alive_reference_hero()
		if is_instance_valid(reference_hero):
			return reference_hero

	if is_instance_valid(main_hero) and not bool(main_hero.get("dead")):
		return main_hero

	var selected_hero := _get_selected_hero()
	if is_instance_valid(selected_hero) and not bool(selected_hero.get("dead")):
		return selected_hero

	return null


func get_nearest_alive_hero_to(target: Node3D) -> Node3D:
	if not is_instance_valid(target):
		return null

	var heroes: Array[Node3D] = []

	if is_instance_valid(party_manager):
		heroes = party_manager.get_alive_heroes()
	elif is_instance_valid(main_hero) and not bool(main_hero.get("dead")):
		heroes.append(main_hero)

	var nearest_hero: Node3D = null
	var nearest_distance: float = INF
	var target_pos := Vector2(
		target.global_position.x,
		target.global_position.z
	)

	for hero in heroes:
		if not is_instance_valid(hero) or bool(hero.get("dead")):
			continue

		var hero_pos := Vector2(
			hero.global_position.x,
			hero.global_position.z
		)

		var distance := hero_pos.distance_to(target_pos)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_hero = hero

	return nearest_hero

func process_skills() -> void:
	var heroes: Array[Node3D] = []

	if is_instance_valid(party_manager):
		heroes = party_manager.get_alive_heroes()
	elif is_instance_valid(main_hero) and not bool(main_hero.get("dead")):
		heroes.append(main_hero)

	if heroes.is_empty():
		return

	# Guarda o alvo de cada herói e verifica se todos podem iniciar o combate.
	var hero_targets: Dictionary = {}
	var has_valid_target := false
	var all_heroes_in_attack_range := true

	for hero in heroes:
		if not is_instance_valid(hero) or bool(hero.get("dead")):
			continue

		var target: Node3D = null

		if is_instance_valid(combat_controller):
			target = combat_controller.get_valid_target_for_hero(hero)

		if not is_instance_valid(target):
			if is_instance_valid(combat_controller):
				target = combat_controller.find_target_for_hero(hero)

		if not is_instance_valid(target):
			if (
				is_instance_valid(current_enemy)
				and not current_enemy.dying
				and current_enemy.health > 0
			):
				target = current_enemy

		# Um herói vivo sem alvo não deve ser ignorado na decisão de parada.
		if not is_instance_valid(target):
			all_heroes_in_attack_range = false
			continue

		if target.dying or target.health <= 0:
			all_heroes_in_attack_range = false
			continue

		has_valid_target = true
		hero_targets[hero.get_instance_id()] = target

		if is_instance_valid(combat_controller):
			combat_controller.set_target(hero, target)

		# Para heróis corpo a corpo, a parada do mundo deve respeitar
		# o alcance real de ataque, não apenas o alcance de detecção.
		var range_value = hero.get("attack_range")

		if range_value == null:
			all_heroes_in_attack_range = false
			continue

		# Calcula a distância horizontal entre o herói e o alvo.
		var hero_position := Vector2(
			hero.global_position.x,
			hero.global_position.z
		)

		var target_position := Vector2(
			target.global_position.x,
			target.global_position.z
		)

		var distance := hero_position.distance_to(target_position)

		if distance > float(range_value) + 0.01:
			all_heroes_in_attack_range = false

	# Mantém o cenário avançando até todos os heróis vivos
	# terem um alvo válido e estarem dentro do próprio alcance.
	if not has_valid_target or not all_heroes_in_attack_range:
		if not world_scroller.running:
			continue_running()
		return

	# Todos os heróis estão em alcance: para o cenário.
	if world_scroller.running:
		world_scroller.running = false

	# Processa as habilidades individualmente, sem alterar a rotação
	# de skills ou os cooldowns de cada personagem.
	for hero in heroes:
		if not is_instance_valid(hero) or bool(hero.get("dead")):
			continue

		var hero_id := hero.get_instance_id()

		if not hero_targets.has(hero_id):
			continue

		var target: Node3D = hero_targets[hero_id]

		if not is_instance_valid(target):
			continue

		if target.dying or target.health <= 0:
			continue

		var range_value = hero.get("attack_range")

		if range_value == null:
			continue

		var hero_position := Vector2(
			hero.global_position.x,
			hero.global_position.z
		)

		var target_position := Vector2(
			target.global_position.x,
			target.global_position.z
		)

		var distance := hero_position.distance_to(target_position)

		if distance > float(range_value) + 0.01:
			continue

		if is_instance_valid(combat_controller):
			combat_controller.process_skill_rotation(hero, target)



func has_combat_enemies() -> bool:
	for enemy in combat_enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.dying or enemy.health <= 0:
			continue

		return true

	return false


func has_alive_enemies() -> bool:
	for enemy in enemy_spawner.enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.dying or enemy.health <= 0:
			continue

		return true

	return false


func start_running():
	if is_party_defeated():
		return

	if is_instance_valid(party_manager):
		main_hero = _get_alive_reference_hero()

	state = State.RUNNING

	print("### RUN LIBERADO PELA FUNÇÃO start_running() ###")

	if is_instance_valid(party_manager):
		for hero in party_manager.get_alive_heroes():
			if hero.has_method("start_running"):
				hero.call("start_running")
	else:
		main_hero.start_running()

	print("=== RUNNING | ONDA ", current_wave, " ===")

	world_scroller.running = true


func start_combat(enemy: Node3D):
	if not is_instance_valid(enemy):
		return

	if is_party_defeated():
		return

	if enemy.dying or enemy.health <= 0:
		return

	# Registra o inimigo que iniciou o combate da equipe.
	if not combat_enemies.has(enemy):
		combat_enemies.append(enemy)

	if state == State.COMBAT:
		if not is_instance_valid(current_enemy):
			select_next_enemy()
		return

	if state != State.RUNNING:
		return

	state = State.COMBAT
	current_enemy = enemy

	if is_instance_valid(combat_controller):
		if not combat_controller.combat_active:
			combat_controller.start_combat()

		# Inicializa/alimenta o alvo de cada herói registrado, sem classe fixa.
		var active_heroes: Array[Node3D] = []
		if is_instance_valid(party_manager):
			active_heroes = party_manager.get_alive_heroes()
		elif is_instance_valid(main_hero):
			active_heroes.append(main_hero)

		for hero in active_heroes:
			if not is_instance_valid(hero):
				continue
			var hero_target: Node3D = combat_controller.find_target_for_hero(hero)
			if not is_instance_valid(hero_target):
				hero_target = enemy
			combat_controller.set_target(hero, hero_target)

	print("=== COMBAT ===")


func select_next_enemy():
	if is_instance_valid(current_enemy):
		if not current_enemy.dying and current_enemy.health > 0:
			var nearest_hero := get_nearest_alive_hero_to(current_enemy)

			if is_instance_valid(nearest_hero):
				var current_distance := Vector2(
					nearest_hero.global_position.x,
					nearest_hero.global_position.z
				).distance_to(Vector2(
					current_enemy.global_position.x,
					current_enemy.global_position.z
				))

				var hero_range = nearest_hero.get("attack_range")

				if hero_range == null:
					hero_range = 0.0

				if current_distance <= float(hero_range):
					return

	current_enemy = null
	var nearest_distance := INF

	for enemy in combat_enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.dying or enemy.health <= 0:
			continue

		var nearest_hero := get_nearest_alive_hero_to(enemy)

		if not is_instance_valid(nearest_hero):
			continue

		var hero_pos := Vector2(
			nearest_hero.global_position.x,
			nearest_hero.global_position.z
		)

		var enemy_pos := Vector2(
			enemy.global_position.x,
			enemy.global_position.z
		)

		var distance := hero_pos.distance_to(enemy_pos)
		var hero_range = nearest_hero.get("attack_range")

		if hero_range == null:
			hero_range = 0.0

		if distance > float(hero_range) + 0.01:
			continue

		if distance < nearest_distance:
			nearest_distance = distance
			current_enemy = enemy

	if is_instance_valid(current_enemy):
		print("=== PRÓXIMO ALVO: ", current_enemy.name, " ===")


func enemy_died(dead_enemy: Node3D):
	if not is_instance_valid(dead_enemy):
		return

	if state != State.COMBAT:
		return

	print("=== INIMIGO MORREU: ", dead_enemy.name, " ===")

	# Cancela ataques que ainda apontam para o inimigo morto.
	if is_instance_valid(party_manager):
		for hero in party_manager.get_heroes():
			if not is_instance_valid(hero):
				continue

			if hero.has_method("cancel_attack_on_target"):
				hero.call("cancel_attack_on_target", dead_enemy)
	else:
		if is_instance_valid(main_hero) and main_hero.has_method("cancel_attack_on_target"):
			main_hero.cancel_attack_on_target(dead_enemy)

	# Remove o inimigo da lista de combate.
	var index := combat_enemies.find(dead_enemy)

	if index >= 0:
		combat_enemies.remove_at(index)
		print("INIMIGO REMOVIDO DO COMBATE: ", dead_enemy.name)

	if current_enemy == dead_enemy:
		current_enemy = null

	if is_instance_valid(combat_controller):
		combat_controller.on_enemy_died(dead_enemy)

	# Boss: mantém o fluxo de vitória existente.
	if current_wave >= 4:
		print("=== BOSS DERROTADO ===")

		var current_level := get_current_level_number()
		var next_level := current_level + 1

		# O progresso da campanha é global e compartilhado pela equipe.
		# Não deve ficar armazenado em CharacterStats de um herói específico.
		var game_manager = get_node_or_null("/root/GameManager")

		if is_instance_valid(game_manager):
			game_manager.unlock_level(next_level)
			print("Próxima fase desbloqueada: ", game_manager.get_unlocked_level())
		else:
			push_warning(
				"LevelController: GameManager não encontrado; "
				+ "não foi possível salvar o desbloqueio da próxima fase."
			)

		print("=== PROGRESSO DA CAMPANHA ===")
		print("Fase concluída: ", current_level)

		var defeated_boss_level := 1
		if _has_property(dead_enemy, "boss_level"):
			defeated_boss_level = maxi(1, int(dead_enemy.get("boss_level")))

		inventory.add_chest(1, defeated_boss_level)
		print(
			"=== BAÚ ADICIONADO | NÍVEL DO BOSS: ",
			defeated_boss_level,
			" ==="
		)

		state = State.VICTORY
		world_scroller.running = false

		var reward_hero := _get_alive_reference_hero()
		if is_instance_valid(reward_hero):
			var reward_stats = reward_hero.get("character_stats")
			if not is_instance_valid(reward_stats):
				reward_stats = reward_hero.get_node_or_null("CharacterStats")

			if is_instance_valid(reward_stats):
				SaveManager.save_character(
					reward_stats,
					inventory,
					str(reward_stats.get("hero_id"))
				)
			else:
				push_warning(
					"LevelController: não foi possível salvar a vitória; "
					+ "CharacterStats do herói vivo não foi encontrado."
				)
		else:
			print(
				"LevelController: nenhum herói vivo para salvar após a vitória."
			)

		print("=== VICTORY ===")

		if SaveManager.automatic_retry:
			print("=== AUTORETRY ATIVADO ===")
			print("=== REINICIANDO EM 3 SEGUNDOS ===")

			await get_tree().create_timer(3.0).timeout

			var current_scene = get_tree().current_scene

			if is_instance_valid(current_scene):
				SceneLoader.change_scene(
					current_scene.scene_file_path
				)

			return

		print("=== AUTORETRY DESATIVADO ===")
		print("=== EXIBINDO PAINEL DE VITÓRIA ===")
		return

	# Procura o próximo alvo sem iniciar o retorno à posição inicial.
	select_next_enemy()

	# Atualiza os alvos de todos os heróis ativos.
	if is_instance_valid(combat_controller) and is_instance_valid(party_manager):
		for hero in party_manager.get_alive_heroes():
			if not is_instance_valid(hero):
				continue
			if is_instance_valid(current_enemy):
				combat_controller.set_target(hero, current_enemy)
				print("=== NOVO ALVO | ", hero.name, ": ", current_enemy.name, " ===")
			else:
				combat_controller.set_target(hero, null)

	# Encontrou um próximo alvo: continua o combate.
	if is_instance_valid(current_enemy):
		print("=== PRÓXIMO ALVO IMEDIATO: ", current_enemy.name, " ===")
		return

	# Ainda existem inimigos vivos na onda?
	if has_alive_enemies():
		print("=== AINDA HÁ INIMIGOS VIVOS: CONTINUANDO AVANÇO ===")
		continue_running()
		return

	# Só inicia a próxima onda quando todos morrerem.
	print("=== TODOS OS INIMIGOS DA ONDA FORAM DERROTADOS ===")

	if is_instance_valid(enemy_spawner):
		await enemy_spawner.advance_wave()



func show_warning(text):
	var label = Label.new()

	label.text = text

	label.add_theme_font_override(
		"font",
		DAMAGE_FONT
	)

	label.add_theme_font_size_override(
		"font_size",
		48
	)

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.set_anchors_preset(Control.PRESET_CENTER)

	label.position = Vector2(-300, -40)
	label.size = Vector2(600, 80)

	get_tree().current_scene.add_child(label)

	var elapsed := 0.0
	var blink_time := 0.2
	var red := false

	while elapsed < 3.0:
		if red:
			label.modulate = Color(1.0, 0.1, 0.1, 1.0)
		else:
			label.modulate = Color.WHITE

		red = not red

		await get_tree().create_timer(blink_time).timeout

		elapsed += blink_time

	if is_instance_valid(label):
		label.queue_free()


func start_reward():
	state = State.REWARD

	print("=== REWARD ===")


func continue_running():
	if is_party_defeated():
		return

	state = State.COMBAT

	print("### RUN LIBERADO PELA FUNÇÃO continue_running() ###")

	world_scroller.running = true

	if is_instance_valid(party_manager):
		for hero in party_manager.get_alive_heroes():
			if hero.has_method("start_running"):
				hero.call("start_running")
				
	print("=== CONTINUANDO RUN ===")


func toggle_pause():
	if get_tree().paused:
		resume_game()
	else:
		pause_game()


func pause_game():
	if get_tree().paused:
		return

	paused = true

	print("=== JOGO PAUSADO ===")
	print("STATE: ", State.keys()[state])

	get_tree().paused = true


func resume_game():
	if not get_tree().paused:
		return

	print("=== DESPAUSANDO JOGO ===")

	get_tree().paused = false
	paused = false

	print("=== JOGO DESPAUSADO ===")


func _has_property(object: Object, property_name: String) -> bool:
	if not is_instance_valid(object):
		return false
	for property_info in object.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false


func get_current_level_number() -> int:
	var scene := get_tree().current_scene

	if scene == null:
		return 1

	var scene_name := scene.scene_file_path.get_file().get_basename()

	if scene_name.begins_with("level_"):
		var level_text := scene_name.trim_prefix("level_")

		if level_text.is_valid_int():
			return maxi(1, level_text.to_int())

	push_warning("Não foi possível identificar a fase: " + scene_name)
	return 1



func mark_wave_start_positions() -> void:
	wave_start_positions.clear()
	wave_start_position_recorded = false

	if not is_instance_valid(party_manager):
		return

	for hero in party_manager.get_alive_heroes():
		if is_instance_valid(hero):
			wave_start_positions[hero.get_instance_id()] = hero.global_position

	wave_start_position_recorded = not wave_start_positions.is_empty()
	if wave_start_position_recorded:
		print("=== POSIÇÕES INICIAIS DA EQUIPE REGISTRADAS ===")


func prepare_next_wave_transition() -> void:
	# O LevelController controla a parada do cenário.
	world_scroller.running = false
	state = State.REWARD

	if not is_instance_valid(party_manager) or not wave_start_position_recorded:
		return

	var active_heroes := party_manager.get_alive_heroes()
	if active_heroes.size() < 2:
		return

	# O companheiro é a referência de deslocamento quando existe;
	# sem companheiro, usa o primeiro herói ativo.
	var anchor: Node3D = party_manager.get_companion_hero()
	if not is_instance_valid(anchor) or not active_heroes.has(anchor):
		anchor = active_heroes[0]

	var anchor_id := anchor.get_instance_id()
	if not wave_start_positions.has(anchor_id):
		return

	var displacement: Vector3 = anchor.global_position - wave_start_positions[anchor_id]
	displacement.x = 0.0
	displacement.y = 0.0

	# Mantém a lógica anterior: a referência fica onde terminou e os
	# outros heróis avançam a mesma distância no eixo Z.
	for hero in active_heroes:
		if (
			hero == anchor
			or not is_instance_valid(hero)
			or not hero.is_inside_tree()
			or bool(hero.get("dead"))
		):
			continue

		var target_z: float = hero.global_position.z + displacement.z
		await move_hero_to_z(hero, target_z)

	print("=== FORMAÇÃO SINCRONIZADA ===")
	print("Deslocamento da formação: ", displacement)


func resume_after_wave_transition() -> void:
	if is_party_defeated():
		return

	if is_instance_valid(party_manager):
		main_hero = _get_alive_reference_hero()
		for hero in party_manager.get_alive_heroes():
			if is_instance_valid(hero) and hero.has_method("start_running"):
				hero.call("start_running")
	elif is_instance_valid(main_hero) and not bool(main_hero.get("dead")) and main_hero.has_method("start_running"):
		main_hero.start_running()

	world_scroller.running = true
	state = State.RUNNING
	print("=== RUNNING | FORMAÇÃO SINCRONIZADA ===")


func move_hero_to_z(hero: Node3D, target_z: float, speed: float = 3.5) -> void:
	if not is_instance_valid(hero) or not hero.is_inside_tree() or bool(hero.get("dead")):
		return

	if hero.has_method("start_running"):
		hero.call("start_running")

	while is_instance_valid(hero) and hero.is_inside_tree():
		if bool(hero.get("dead")):
			return

		var current_position: Vector3 = hero.global_position
		var remaining_z: float = target_z - current_position.z
		if absf(remaining_z) <= 0.02:
			break

		var delta: float = get_process_delta_time()
		current_position.z = move_toward(
			current_position.z,
			target_z,
			speed * delta
		)
		hero.global_position = current_position
		await get_tree().process_frame

	# O herói pode ter sido removido da cena enquanto aguardava o próximo frame.
	if is_instance_valid(hero) and hero.is_inside_tree():
		hero.global_position.z = target_z
		if hero.has_method("play_animation"):
			hero.call("play_animation", "idle")
