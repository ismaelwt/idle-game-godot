extends TextureButton


const CharacterSelectionDataScript = preload("res://Script/character_selection_data.gd")
var slot_index: int = 0
var is_drag_source := false


func _ready():

	# Descobre automaticamente o slot pelo nome do nó
	match name:

		"Skill1":
			slot_index = 0

		"Skill2":
			slot_index = 1

		"Skill3":
			slot_index = 2

		_:
			Log.d(
				"ERRO: Nome de slot desconhecido: ",
				name
			)


	# Os filhos não podem bloquear o Drag & Drop
	var icon = get_node_or_null("Icon")

	if icon:
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


	var label = get_node_or_null("Label")

	if label:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE


	Log.d(
		"SKILL SLOT CONFIGURADO: ",
		name,
		" | Índice: ",
		slot_index
	)


func _get_drag_data(_at_position):

	var hero = _get_main_hero()

	if not is_instance_valid(hero):

		Log.d("DRAG ERRO: herói principal não encontrado.")

		return null


	var character_stats = hero.character_stats


	if slot_index >= character_stats.skill_order.size():

		Log.d(
			"DRAG ERRO: Slot ",
			slot_index + 1,
			" está vazio."
		)

		return null


	var skill_id = character_stats.skill_order[slot_index]


	if not character_stats.has_skill(skill_id):

		Log.d(
			"DRAG ERRO: Skill ",
			skill_id,
			" não está desbloqueada."
		)

		return null


	Log.d("====================================")
	Log.d("=== INÍCIO DO DRAG ===")
	Log.d("Slot origem: ", slot_index + 1)
	Log.d("Skill: ", skill_id)
	Log.d(
		"Ordem atual: ",
		character_stats.skill_order
	)
	Log.d("====================================")


	# ==========================================
	# PREVIEW
	# ==========================================

	var preview = TextureRect.new()

	var icon = get_node_or_null("Icon")

	if icon:
		preview.texture = icon.texture

	preview.custom_minimum_size = Vector2(
		80,
		80
	)

	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	set_drag_preview(preview)


	return {
		"from_index": slot_index
	}


func _can_drop_data(_at_position, data):

	if not data is Dictionary:
		return false


	if not data.has("from_index"):
		return false


	var hero = _get_main_hero()

	if not is_instance_valid(hero):
		return false


	var character_stats = hero.character_stats

	var from_index = int(
		data["from_index"]
	)


	Log.d(
		"CAN DROP -> DESTINO SLOT ",
		slot_index + 1
	)


	if from_index < 0:
		return false


	if from_index >= character_stats.skill_order.size():
		return false


	if slot_index < 0:
		return false


	if slot_index >= character_stats.skill_order.size():
		return false


	return true


func _drop_data(_at_position, data):

	if not data is Dictionary:
		return


	var hero = _get_main_hero()

	if not is_instance_valid(hero):

		Log.d(
			"DROP ERRO: herói principal não encontrado."
		)

		return


	var character_stats = hero.character_stats

	var from_index = int(
		data["from_index"]
	)


	Log.d("====================================")
	Log.d("=== DROP RECEBIDO ===")
	Log.d("Origem: Slot ", from_index + 1)
	Log.d("Destino: Slot ", slot_index + 1)
	Log.d("====================================")


	if from_index == slot_index:

		Log.d(
			"DROP IGNORADO: mesma posição."
		)

		return


	var order = character_stats.skill_order.duplicate()


	if from_index < 0 or from_index >= order.size():

		Log.d(
			"DROP ERRO: posição de origem inválida."
		)

		return


	if slot_index < 0 or slot_index >= order.size():

		Log.d(
			"DROP ERRO: posição de destino inválida."
		)

		return


	Log.d(
		"ORDEM ANTES: ",
		order
	)


	Log.d(
		"MOVENDO ",
		order[from_index],
		" DO SLOT ",
		from_index + 1,
		" PARA O SLOT ",
		slot_index + 1
	)


	# ==========================================
	# TROCA
	# ==========================================

	var temp = order[from_index]

	order[from_index] = order[slot_index]

	order[slot_index] = temp


	# ==========================================
	# SALVA
	# ==========================================

	character_stats.set_skill_order(order)


	Log.d(
		"ORDEM DEPOIS: ",
		character_stats.skill_order
	)

	Log.d(
		"=== ALTERAÇÃO CONCLUÍDA ==="
	)

	Log.d("====================================")


func _get_main_hero() -> Node:
	var manager := get_tree().get_first_node_in_group("party_manager") as PartyManager
	if is_instance_valid(manager):
		var main_hero := manager.get_main_hero()
		if is_instance_valid(main_hero):
			return main_hero

	var selected_id := CharacterSelectionData.get_selected_character_id()
	for candidate in get_tree().get_nodes_in_group("party_heroes"):
		if not is_instance_valid(candidate):
			continue
		var stats = candidate.get("character_stats")
		if not is_instance_valid(stats):
			stats = candidate.get_node_or_null("CharacterStats")
		if is_instance_valid(stats):
			var hero_id := CharacterSelectionDataScript.normalize_hero_id(str(stats.get("hero_id")))
			if hero_id == selected_id:
				return candidate
	return null
