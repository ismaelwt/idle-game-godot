
extends Node
class_name Inventory

const CharacterSelectionDataScript = preload("res://Script/character_selection_data.gd")

signal equipment_changed
signal inventory_changed

# Equipamentos recebidos pelo jogador.
var equipment: Array[ItemInstance] = []

# Identificador do herói que as chamadas antigas (sem hero_id) devem usar.
# A interface de status atualiza este valor ao selecionar um personagem.
var active_hero_id: String = "mage"

# Equipamentos separados por herói: equipped_by_hero[hero_id][item_type] = ItemInstance.
var equipped_by_hero: Dictionary = {}


func _create_empty_equipment() -> Dictionary:
	return {
		ItemBase.ItemType.WEAPON: null,
		ItemBase.ItemType.HELMET: null,
		ItemBase.ItemType.CHEST: null,
		ItemBase.ItemType.GLOVES: null,
		ItemBase.ItemType.PANTS: null,
		ItemBase.ItemType.BOOTS: null
	}


# Compatibilidade com scripts antigos: equipped_items aponta para o herói ativo.
var equipped_items: Dictionary:
	get:
		return get_equipped_items(active_hero_id)


func get_equipped_items(hero_id: String = "") -> Dictionary:
	var resolved_id := hero_id if not hero_id.is_empty() else active_hero_id
	if not equipped_by_hero.has(resolved_id) or not equipped_by_hero[resolved_id] is Dictionary:
		equipped_by_hero[resolved_id] = _create_empty_equipment()
	return equipped_by_hero[resolved_id]


func set_equipped_items(hero_id: String, items: Dictionary) -> void:
	var normalized := _create_empty_equipment()
	for item_type in normalized.keys():
		normalized[item_type] = items.get(item_type, null)
	equipped_by_hero[hero_id] = normalized
	equipment_changed.emit()

# Quantidade de baús disponíveis para abrir.
var chest_count: int = 0

# Gerador de equipamentos.
var item_generator := ItemGenerator.new()


func add_chest(amount: int = 1) -> void:
	if amount <= 0:
		return

	chest_count += amount
	inventory_changed.emit()

	print("=== BAÚ ADICIONADO ===")
	print("Total de baús: ", chest_count)

	_save_inventory()


func add_equipment(item: ItemInstance) -> void:
	if item == null:
		return

	equipment.append(item)
	inventory_changed.emit()

	print("=== EQUIPAMENTO ADICIONADO ===")

	if item.item_base != null:
		print("Item: ", item.item_base.item_name)
		print("Raridade: ", ItemBase.Rarity.keys()[item.generated_rarity])

	print("Total de equipamentos: ", equipment.size())

	_save_inventory()


func sell_all_equipment() -> int:
	if equipment.is_empty():
		print("Não há itens na mochila para vender.")
		return 0

	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_error("Inventory: GameManager Autoload não encontrado; venda cancelada.")
		return 0

	var total_value: int = 0
	var sold_count: int = 0

	for item in equipment:
		if item == null:
			continue

		total_value += maxi(item.item_value, 0)
		sold_count += 1

	# Só remove os itens depois de confirmar que o saldo global está disponível.
	game_manager.add_gold(total_value)
	equipment.clear()
	inventory_changed.emit()

	_save_inventory()

	print("=== VENDA DO INVENTÁRIO ===")
	print("Itens vendidos: ", sold_count)
	print("Ouro recebido: ", total_value)
	print("Ouro global total: ", game_manager.gold)

	return total_value


func _save_inventory() -> void:
	if not is_instance_valid(SaveManager):
		push_warning("Inventory: SaveManager não encontrado; inventário não salvo.")
		return

	SaveManager.save_inventory(self)


func open_chest() -> ItemInstance:
	if chest_count <= 0:
		print("Não há baús disponíveis.")
		return null

	# Gera o equipamento antes de consumir o baú.
	var current_scene := get_tree().current_scene

	if current_scene == null:
		push_warning("Inventory: cena atual não encontrada.")
		return null

	var selected_hero := _find_hero_by_id(active_hero_id)
	if not is_instance_valid(selected_hero):
		var party_manager = get_tree().get_first_node_in_group("party_manager")
		if is_instance_valid(party_manager):
			selected_hero = party_manager.get_main_hero()

	var hero_level: int = 1
	if is_instance_valid(selected_hero):
		var stats = selected_hero.get("character_stats")
		if is_instance_valid(stats):
			hero_level = maxi(1, int(stats.get("level")))
	# Os baús podem conceder itens de qualquer classe, independentemente
	# do herói selecionado. O nível continua baseado nesse herói.
	var item := item_generator.generate_chest_item(
		hero_level,
		ItemBase.ItemClass.ALL
	)

	if item == null:
		push_error("Inventory: falha ao gerar equipamento. O baú não foi consumido.")
		return null

	# Consome um baú e guarda o equipamento.
	chest_count -= 1
	add_equipment(item)
	inventory_changed.emit()

	print("=== BAÚ ABERTO ===")
	print("Baús restantes: ", chest_count)

	return item


func equip_item(item: ItemInstance, hero_id: String = "") -> bool:
	if item == null or item.item_base == null:
		return false

	var resolved_id := hero_id if not hero_id.is_empty() else active_hero_id
	var hero_equipment := get_equipped_items(resolved_id)
	var item_type: ItemBase.ItemType = item.item_base.item_type

	# Por enquanto, acessórios não possuem espaço de equipamento.
	if not hero_equipment.has(item_type):
		print("Esse tipo de item não possui espaço para equipar.")
		return false

	var inventory_index: int = equipment.find(item)
	if inventory_index == -1:
		print("Esse item não está na mochila.")
		return false

	var normalized_hero_id := CharacterSelectionDataScript.normalize_hero_id(resolved_id)
	var required_class: ItemBase.ItemClass = item.item_base.item_class
	var hero_class: ItemBase.ItemClass
	match normalized_hero_id:
		"mage":
			hero_class = ItemBase.ItemClass.MAGE
		"knight":
			hero_class = ItemBase.ItemClass.KNIGHT
		"archer":
			hero_class = ItemBase.ItemClass.ARCHER
		_:
			push_warning("Inventory: classe desconhecida para o herói '%s'." % resolved_id)
			return false

	if required_class != ItemBase.ItemClass.ALL and required_class != hero_class:
		print(
			"Não foi possível equipar %s. Classe exigida: %s | Classe do herói: %s"
			% [
				item.item_base.item_name,
				ItemBase.ItemClass.keys()[required_class],
				ItemBase.ItemClass.keys()[hero_class]
			]
		)
		return false

	var hero_level: int = 1
	var current_scene := get_tree().current_scene
	if current_scene != null:
		var party_manager = get_tree().get_first_node_in_group("party_manager")
		var hero: Node = null
		if is_instance_valid(party_manager) and party_manager.has_method("get_heroes"):
			for candidate in party_manager.get_heroes():
				if is_instance_valid(candidate) and is_instance_valid(candidate.get("character_stats")):
					if str(candidate.character_stats.get("hero_id")) == resolved_id:
						hero = candidate
						break
		if hero == null:
			hero = _find_hero_by_id(resolved_id)
		if is_instance_valid(hero) and is_instance_valid(hero.get("character_stats")):
			hero_level = int(hero.character_stats.level)

	if item.item_level > hero_level:
		print(
			"Não foi possível equipar %s. Nível do item: %d | Nível do herói: %d"
			% [item.item_base.item_name, item.item_level, hero_level]
		)
		return false

	var previous_item: ItemInstance = hero_equipment[item_type]
	equipment.remove_at(inventory_index)
	if previous_item != null:
		equipment.append(previous_item)

	hero_equipment[item_type] = item
	equipment_changed.emit()
	inventory_changed.emit()

	print("=== EQUIPAMENTO ALTERADO | HERÓI: ", resolved_id, " ===")
	print("Item equipado: ", item.item_base.item_name)
	if previous_item != null:
		print("Item devolvido à mochila: ", previous_item.item_base.item_name)

	_save_inventory()
	_save_hero_equipment(resolved_id)
	return true

func install_gem(
	equipment_item: ItemInstance,
	gem_item: ItemInstance,
	hero_id: String = ""
) -> bool:
	if (
		equipment_item == null
		or equipment_item.item_base == null
		or gem_item == null
		or gem_item.item_base == null
	):
		return false

	if equipment_item.item_base.item_type == ItemBase.ItemType.GEM:
		return false
	if gem_item.item_base.item_type != ItemBase.ItemType.GEM:
		return false
	if equipment_item.installed_enchantments.size() >= equipment_item.enchantment_slots:
		return false

	var gem_index := equipment.find(gem_item)
	if gem_index < 0:
		return false

	var resolved_id := hero_id if not hero_id.is_empty() else active_hero_id
	var is_equipped := false
	for equipped in get_equipped_items(resolved_id).values():
		if equipped == equipment_item:
			is_equipped = true
			break

	var is_in_inventory := equipment.has(equipment_item)
	if not is_equipped and not is_in_inventory:
		return false

	equipment.remove_at(gem_index)
	equipment_item.installed_enchantments.append(gem_item)

	equipment_changed.emit()
	inventory_changed.emit()
	_save_inventory()

	if is_equipped:
		_save_hero_equipment(resolved_id)

	print(
		"=== GEMA INSTALADA === | GEMA: ",
		gem_item.item_base.item_name,
		" | EQUIPAMENTO: ",
		equipment_item.item_base.item_name
	)
	return true


func unequip_item(item_type: ItemBase.ItemType, hero_id: String = "") -> bool:
	var resolved_id := hero_id if not hero_id.is_empty() else active_hero_id
	var hero_equipment := get_equipped_items(resolved_id)
	if not hero_equipment.has(item_type):
		return false

	var item: ItemInstance = hero_equipment[item_type]
	if item == null:
		return false

	equipment.append(item)
	hero_equipment[item_type] = null
	equipment_changed.emit()
	inventory_changed.emit()

	print("=== EQUIPAMENTO REMOVIDO | HERÓI: ", resolved_id, " ===")
	print("Item: ", item.item_base.item_name if item.item_base != null else "Item")

	_save_inventory()
	_save_hero_equipment(resolved_id)
	return true


func _save_hero_equipment(hero_id: String) -> void:
	var hero = _find_hero_by_id(hero_id)
	if is_instance_valid(hero):
		var stats = hero.get("character_stats")
		if is_instance_valid(stats):
			SaveManager.save_character(stats, self, hero_id)


func _find_hero_by_id(hero_id: String) -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	var normalized_id := CharacterSelectionData.normalize_hero_id(hero_id)

	# O gerenciamento de inventário deve encontrar o herói mesmo morto.
	# Não usar get_alive_heroes() para localizar dono de equipamento.
	var party_manager := current_scene.find_child("PartyManager", true, false)
	if is_instance_valid(party_manager) and party_manager.has_method("get_heroes"):
		for hero in party_manager.get_heroes():
			if not is_instance_valid(hero):
				continue

			var stats = hero.get("character_stats")
			if not is_instance_valid(stats):
				stats = hero.get_node_or_null("CharacterStats")
			if not is_instance_valid(stats):
				continue

			var candidate_id := CharacterSelectionData.normalize_hero_id(
				str(stats.get("hero_id"))
			)
			if candidate_id == normalized_id:
				return hero

	# Compatibilidade com heróis que ainda estejam registrados apenas no grupo.
	for candidate in get_tree().get_nodes_in_group("party_heroes"):
		if not is_instance_valid(candidate):
			continue

		var stats = candidate.get("character_stats")
		if not is_instance_valid(stats):
			stats = candidate.get_node_or_null("CharacterStats")
		if not is_instance_valid(stats):
			continue

		var candidate_id := CharacterSelectionData.normalize_hero_id(
			str(stats.get("hero_id"))
		)
		if candidate_id == normalized_id:
			return candidate

	return null
