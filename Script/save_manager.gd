extends Node

const SAVE_PATH := "user://savegame.json"

var automatic_retry: bool = false


func _read_save_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: não foi possível abrir o save para leitura.")
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Dictionary:
		return parsed

	push_warning("SaveManager: save inválido; usando dados vazios.")
	return {}


func _write_save_data(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: não foi possível gravar o save.")
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_global_data() -> Dictionary:
	var data := _read_save_data()
	var global_data: Dictionary = data.get("global", {})

	# Migração de saves antigos: os dados globais ficavam na raiz.
	if not global_data.has("gold"):
		global_data["gold"] = int(data.get("gold", 0))
	if not global_data.has("opened_chests"):
		global_data["opened_chests"] = data.get("opened_chests", {})
	if not global_data.has("flags"):
		global_data["flags"] = data.get("global_flags", {})
	if not global_data.has("unlocked_level"):
		var legacy_level := int(data.get("unlocked_level", 1))
		var heroes: Dictionary = data.get("heroes", {})
		if heroes.has("player") and heroes["player"] is Dictionary:
			legacy_level = maxi(legacy_level, int(heroes["player"].get("unlocked_level", 1)))
		global_data["unlocked_level"] = maxi(1, legacy_level)

	return global_data


func save_global_data(global_data: Dictionary) -> bool:
	var data := _read_save_data()
	var saved_global: Dictionary = data.get("global", {})

	for key in global_data.keys():
		saved_global[key] = global_data[key]

	data["global"] = saved_global
	_remove_legacy_root_fields(data)
	return _write_save_data(data)


func _remove_legacy_root_fields(data: Dictionary) -> void:
	# A fonte oficial fica em global/heroes, sem atributos duplicados na raiz.
	var legacy_keys := [
		"gold", "opened_chests", "global_flags",
		"strength", "agility", "intelligence", "vitality",
		"level", "xp", "xp_to_next_level", "mana",
		"attribute_points", "skill_points", "basic_attack_level",
		"stage_progress", "unlocked_stage", "unlocked_level",
		"unlocked_skills", "skill_order"
	]
	for key in legacy_keys:
		data.erase(key)


func save_global_gold(amount: int) -> bool:
	var global_data := load_global_data()
	global_data["gold"] = maxi(0, amount)
	return save_global_data(global_data)


# Salva somente o inventário compartilhado, preservando os dados globais
# e a progressão individual de todos os heróis. Não depende de um nó de personagem específico na cena.
func save_inventory(inventory: Inventory) -> bool:
	if inventory == null or not is_instance_valid(inventory):
		push_warning("SaveManager: inventário inválido; não foi salvo.")
		return false

	var data := _read_save_data()
	data["inventory"] = serialize_inventory(inventory)

	# Sincroniza o ouro global sem apagar outros dados persistentes.
	var game_manager = get_node_or_null("/root/GameManager")
	var global_data: Dictionary = data.get("global", {})
	if is_instance_valid(game_manager):
		global_data["gold"] = int(game_manager.gold)
		global_data["opened_chests"] = game_manager.opened_chests.duplicate(true)
		global_data["unlocked_level"] = maxi(
			int(global_data.get("unlocked_level", 1)),
			int(game_manager.unlocked_level)
		)
		global_data["flags"] = game_manager.global_flags.duplicate(true)
		data["global"] = global_data

	_remove_legacy_root_fields(data)
	var success := _write_save_data(data)
	if success:
		print("SaveManager: inventário compartilhado salvo.")
	return success


func save_character(character_stats, inventory = null, hero_id: String = "") -> void:
	if character_stats == null or not is_instance_valid(character_stats):
		push_warning("SaveManager: CharacterStats inválido; personagem não salvo.")
		return
	if hero_id.is_empty():
		hero_id = str(character_stats.get("hero_id"))
	if hero_id.is_empty() or hero_id == "<null>":
		hero_id = "mage"
	hero_id = CharacterSelectionData.normalize_hero_id(hero_id)

	var data := _read_save_data()
	var heroes: Dictionary = data.get("heroes", {})
	var hero_data := _serialize_character_stats(character_stats)

	# Equipamentos vestidos pertencem ao herói; a mochila continua global.
	if inventory != null:
		hero_data["equipment"] = serialize_hero_equipment(inventory, hero_id)
	elif heroes.get(hero_id, {}) is Dictionary:
		var previous_hero: Dictionary = heroes.get(hero_id, {})
		if previous_hero.has("equipment"):
			hero_data["equipment"] = previous_hero["equipment"]

	heroes[hero_id] = hero_data
	data["heroes"] = heroes

	var global_data: Dictionary = data.get("global", {})
	var game_manager = get_node_or_null("/root/GameManager")
	if is_instance_valid(game_manager):
		global_data["gold"] = int(game_manager.gold)
		global_data["opened_chests"] = game_manager.opened_chests.duplicate(true)
		global_data["flags"] = game_manager.global_flags.duplicate(true)
		global_data["unlocked_level"] = maxi(
			int(global_data.get("unlocked_level", 1)),
			int(game_manager.unlocked_level)
		)
	else:
		global_data["gold"] = int(global_data.get("gold", 0))
		global_data["opened_chests"] = global_data.get("opened_chests", {})
		global_data["flags"] = global_data.get("flags", {})
		global_data["unlocked_level"] = maxi(
			1,
			int(global_data.get("unlocked_level", 1))
		)
	data["global"] = global_data
	data["automatic_retry"] = automatic_retry

	if inventory != null:
		data["inventory"] = serialize_inventory(inventory)

	# Mantém os dados compartilhados em global e remove duplicações antigas.
	if not global_data.is_empty():
		data["global"] = global_data
	_remove_legacy_root_fields(data)

	if _write_save_data(data):
		print("=== JOGO SALVO | HERÓI: ", hero_id, " ===")


func load_character(character_stats, inventory = null, hero_id: String = "") -> void:
	if character_stats == null or not is_instance_valid(character_stats):
		push_warning("SaveManager: CharacterStats inválido; personagem não carregado.")
		return
	if hero_id.is_empty():
		hero_id = str(character_stats.get("hero_id"))
	if hero_id.is_empty() or hero_id == "<null>":
		hero_id = "mage"
	hero_id = CharacterSelectionData.normalize_hero_id(hero_id)

	if not FileAccess.file_exists(SAVE_PATH):
		print("Nenhum save encontrado.")
		return

	var data := _read_save_data()
	if data.is_empty():
		return

	var global_data: Dictionary = load_global_data()
	var global_gold := int(global_data.get("gold", 0))
	var game_manager = get_node_or_null("/root/GameManager")
	if is_instance_valid(game_manager):
		game_manager.set_gold(global_gold, false)

	var heroes: Dictionary = data.get("heroes", {})
	var hero_data: Dictionary = {}

	if heroes.has(hero_id) and heroes[hero_id] is Dictionary:
		hero_data = heroes[hero_id]
	elif hero_id == "mage" and heroes.has("player") and heroes["player"] is Dictionary:
		# Migra o progresso do ID antigo "player" para o Mage.
		hero_data = heroes["player"]
	elif hero_id == "mage" and data.has("level"):
		# Compatibilidade com saves antigos que guardavam atributos na raiz.
		hero_data = data
	else:
		print("SaveManager: nenhum save individual para o herói: ", hero_id)
		return

	_apply_character_stats(character_stats, hero_data)
	if inventory != null:
		var inventory_data = data.get("inventory", {})
		if inventory_data is Dictionary:
			deserialize_inventory(inventory, inventory_data)
		# Dados individuais do herói têm precedência; migra o equipamento legado do herói antigo.
		var saved_hero_equipment: Dictionary = hero_data.get("equipment", {})
		if saved_hero_equipment.is_empty() and hero_id == "mage":
			saved_hero_equipment = data.get("inventory", {}).get("equipped_items", {})
		deserialize_hero_equipment(inventory, hero_id, saved_hero_equipment)

	automatic_retry = bool(data.get("automatic_retry", false))
	if is_instance_valid(game_manager):
		game_manager.load_global_components(global_data)

	print("=== SAVE CARREGADO | HERÓI: ", hero_id, " ===")


func _serialize_character_stats(character_stats) -> Dictionary:
	return {
		"level": character_stats.level,
		"xp": character_stats.xp,
		"xp_to_next_level": character_stats.xp_to_next_level,
		"attribute_points": character_stats.attribute_points,
		"skill_points": character_stats.skill_points,
		"stage_progress": character_stats.stage_progress,
		"unlocked_stage": character_stats.unlocked_stage,
		"strength": character_stats.strength,
		"agility": character_stats.agility,
		"intelligence": character_stats.intelligence,
		"vitality": character_stats.vitality,
		"basic_attack_level": character_stats.basic_attack_level,
		"mana": character_stats.mana,
		"unlocked_skills": character_stats.unlocked_skills.duplicate(),
		"skill_order": character_stats.skill_order.duplicate()
	}


func _apply_character_stats(character_stats, data: Dictionary) -> void:
	character_stats.level = int(data.get("level", 1))
	character_stats.xp = int(data.get("xp", 0))
	character_stats.xp_to_next_level = int(data.get("xp_to_next_level", 100))
	character_stats.attribute_points = int(data.get("attribute_points", 0))
	character_stats.skill_points = int(data.get("skill_points", 0))
	character_stats.stage_progress = int(data.get("stage_progress", 0))
	character_stats.unlocked_stage = int(data.get("unlocked_stage", 0))
	character_stats.strength = int(data.get("strength", 5))
	character_stats.agility = int(data.get("agility", 5))
	character_stats.intelligence = int(data.get("intelligence", 5))
	character_stats.vitality = int(data.get("vitality", 5))
	character_stats.basic_attack_level = int(data.get("basic_attack_level", 0))
	character_stats.mana = float(data.get("mana", character_stats.max_mana))

	character_stats.unlocked_skills.clear()
	for skill_id in data.get("unlocked_skills", []):
		character_stats.unlocked_skills.append(str(skill_id))

	character_stats.skill_order.clear()
	for skill_id in data.get("skill_order", []):
		character_stats.skill_order.append(str(skill_id))


func serialize_item(item: ItemInstance) -> Dictionary:
	return {
		"item_id": str(item.item_base.item_id),
		"instance_id": item.instance_id,
		"item_level": item.item_level,
		"generated_rarity": item.generated_rarity,
		"item_value": item.item_value,

		"strength_bonus": item.strength_bonus,
		"agility_bonus": item.agility_bonus,
		"intelligence_bonus": item.intelligence_bonus,
		"vitality_bonus": item.vitality_bonus,
		"max_mana_bonus": item.max_mana_bonus,
		"physical_damage_bonus": item.physical_damage_bonus,
		"magic_damage_bonus": item.magic_damage_bonus,
		"magic_power_bonus": item.magic_power_bonus,
		"physical_defense_bonus": item.physical_defense_bonus,
		"magic_defense_bonus": item.magic_defense_bonus,
		"life_steal_bonus": item.life_steal_bonus,
		"mana_steal_bonus": item.mana_steal_bonus,

		"gem_effect": int(item.gem_effect),
		"gem_effect_value": item.gem_effect_value,

		"enchantment_slots": item.enchantment_slots,
		"installed_enchantments": _serialize_installed_gems(item)
	}


func _serialize_installed_gems(item: ItemInstance) -> Array[Dictionary]:
	var gems: Array[Dictionary] = []
	for enchantment in item.installed_enchantments:
		if enchantment is ItemInstance and enchantment.item_base != null:
			gems.append(serialize_item(enchantment))
	return gems


func serialize_hero_equipment(inventory: Inventory, hero_id: String) -> Dictionary:
	var data: Dictionary = {}
	var hero_equipment := inventory.get_equipped_items(hero_id)
	for item_type in hero_equipment:
		var item: ItemInstance = hero_equipment[item_type]
		if item == null or item.item_base == null:
			continue
		var type_name: String = ItemBase.ItemType.keys()[int(item_type)]
		data[type_name] = serialize_item(item)
	return data


func deserialize_hero_equipment(inventory: Inventory, hero_id: String, saved_equipped: Dictionary) -> void:
	var database := ItemDatabase.new()
	var loaded: Dictionary = inventory._create_empty_equipment()

	for type_name in saved_equipped:
		if not saved_equipped[type_name] is Dictionary:
			continue
		var item_type: int = ItemBase.ItemType.get(type_name, -1)
		if not loaded.has(item_type):
			continue
		var item := deserialize_item(saved_equipped[type_name], database)
		if item == null:
			continue
		if int(item.item_base.item_type) != item_type:
			push_warning("SaveManager: tipo incompatível no espaço " + str(type_name))
			continue
		loaded[item_type] = item

	inventory.set_equipped_items(hero_id, loaded)


func serialize_inventory(inventory: Inventory) -> Dictionary:
	var data: Dictionary = {
		"chest_count": inventory.chest_count,
		"equipment": [],
		"equipped_by_hero": {}
	}

	for item in inventory.equipment:
		if item == null or item.item_base == null:
			continue
		data["equipment"].append(serialize_item(item))

	for hero_id in inventory.equipped_by_hero:
		data["equipped_by_hero"][str(hero_id)] = serialize_hero_equipment(inventory, str(hero_id))

	# Mantém cópia do equipamento legado para compatibilidade com saves antigos.
	data["equipped_items"] = serialize_hero_equipment(inventory, "player")
	return data


func deserialize_inventory(inventory: Inventory, data: Dictionary) -> void:
	inventory.chest_count = int(data.get("chest_count", 0))
	inventory.equipment.clear()

	var database := ItemDatabase.new()
	for item_data in data.get("equipment", []):
		if not item_data is Dictionary:
			continue
		var item := deserialize_item(item_data, database)
		if item != null:
			inventory.equipment.append(item)

	# Novo formato: os equipamentos vestidos são indexados pelo ID do herói.
	var saved_by_hero: Dictionary = data.get("equipped_by_hero", {})
	for hero_id in saved_by_hero:
		if saved_by_hero[hero_id] is Dictionary:
			deserialize_hero_equipment(inventory, str(hero_id), saved_by_hero[hero_id])

	# Migração: formato antigo tinha somente "equipped_items" para o herói legado.
	if saved_by_hero.is_empty():
		var legacy_equipped: Dictionary = data.get("equipped_items", {})
		if not legacy_equipped.is_empty():
			deserialize_hero_equipment(inventory, "player", legacy_equipped)

	inventory.inventory_changed.emit()
	inventory.equipment_changed.emit()
	print("=== INVENTÁRIO COMPARTILHADO CARREGADO ===")
	print("Baús: ", inventory.chest_count)
	print("Itens na mochila: ", inventory.equipment.size())


func deserialize_item(item_data: Dictionary, database: ItemDatabase) -> ItemInstance:
	var item_id := StringName(str(item_data.get("item_id", "")))
	var base: ItemBase = null

	for candidate in database.get_all_items():
		if candidate.item_id == item_id:
			base = candidate
			break

	if base == null:
		push_warning("SaveManager: item não encontrado no banco: " + str(item_id))
		return null

	var item := ItemInstance.new()
	item.item_base = base
	item.instance_id = str(item_data.get("instance_id", ""))
	item.item_value = int(
		item_data.get("item_value", base.get_item_value())
	)
	item.generated_rarity = int(item_data.get("generated_rarity", base.rarity)) as ItemBase.Rarity

	item.strength_bonus = int(item_data.get("strength_bonus", 0))
	item.agility_bonus = int(item_data.get("agility_bonus", 0))
	item.intelligence_bonus = int(item_data.get("intelligence_bonus", 0))
	item.vitality_bonus = int(item_data.get("vitality_bonus", 0))
	item.max_mana_bonus = int(item_data.get("max_mana_bonus", 0))
	item.physical_damage_bonus = int(item_data.get("physical_damage_bonus", 0))
	item.magic_damage_bonus = int(item_data.get("magic_damage_bonus", 0))
	item.magic_power_bonus = float(item_data.get("magic_power_bonus", 0.0))
	var legacy_defense := int(item_data.get("defense_bonus", 0))
	item.physical_defense_bonus = int(item_data.get("physical_defense_bonus", legacy_defense))
	item.magic_defense_bonus = int(item_data.get("magic_defense_bonus", legacy_defense))
	item.life_steal_bonus = float(item_data.get("life_steal_bonus", 0.0))
	item.mana_steal_bonus = float(item_data.get("mana_steal_bonus", 0.0))
	
	item.item_level = maxi(
		1,
		int(item_data.get("item_level", base.item_level))
	)
	# Restaura os dados específicos das gemas.
	item.gem_effect = int(item_data.get("gem_effect", base.gem_effect)) as ItemBase.GemEffect

	if item_data.has("gem_effect_value"):
		item.gem_effect_value = float(item_data["gem_effect_value"])
	elif base.item_type == ItemBase.ItemType.GEM and base.gem_effect != ItemBase.GemEffect.NONE:
		# Compatibilidade com saves antigos que não guardavam o valor da gema.
		item.gem_effect_value = randf_range(
			base.gem_effect_min,
			base.gem_effect_max
		)
	else:
		item.gem_effect_value = 0.0

	item.enchantment_slots = clampi(
		int(item_data.get("enchantment_slots", 0)),
		0,
		2
	)

	item.installed_enchantments.clear()
	for gem_data in item_data.get("installed_enchantments", []):
		if not gem_data is Dictionary:
			continue
		var installed_gem := deserialize_item(gem_data, database)
		if (
			installed_gem != null
			and installed_gem.item_base.item_type == ItemBase.ItemType.GEM
		):
			item.installed_enchantments.append(installed_gem)

	return item


func save_auto_retry(enabled: bool) -> void:
	var data := _read_save_data()
	data["automatic_retry"] = enabled
	if _write_save_data(data):
		automatic_retry = enabled


func load_auto_retry() -> bool:
	var data := _read_save_data()
	automatic_retry = bool(data.get("automatic_retry", false))
	print("=== AUTO RETRY CARREGADO === ", automatic_retry)
	return automatic_retry
