
extends Node
class_name ItemDatabase

const ITEMS: Array[ItemBase] = [
	preload("res://Items/cajado_sombrio.tres"),
	preload("res://Items/cajado_do_aprendiz.tres"),
	preload("res://Items/frost_hood.tres"),
	preload("res://Items/fire_hood.tres"),
	preload("res://Items/leather_boots.tres"),
	preload("res://Items/terra_rob.tres"),
	preload("res://Items/warlock_gloves.tres"),
	preload("res://Items/prismatic_legs.tres"),
	preload("res://Items/warlock_cloath.tres"),
	preload("res://Items/Gems/gem_esmeralda.tres")
]

# Chances fixas por raridade.
# A quantidade de itens cadastrados não altera estes valores.
const RARITY_CHANCES: Dictionary = {
	ItemBase.Rarity.COMMON: 45,
	ItemBase.Rarity.UNCOMMON: 28,
	ItemBase.Rarity.RARE: 15,
	ItemBase.Rarity.EPIC: 10,
	ItemBase.Rarity.LEGENDARY: 2
}


func get_all_items() -> Array[ItemBase]:
	return ITEMS


func get_items_by_rarity(
	rarity: ItemBase.Rarity,
	item_class: ItemBase.ItemClass = ItemBase.ItemClass.MAGE
) -> Array[ItemBase]:
	var result: Array[ItemBase] = []

	for item in ITEMS:
		if (
			item != null
			and item.rarity == rarity
			and (item.item_class == item_class or item.item_class == ItemBase.ItemClass.ALL)
		):
			result.append(item)

	return result


func get_items_by_class(item_class: ItemBase.ItemClass) -> Array[ItemBase]:
	var result: Array[ItemBase] = []

	for item in ITEMS:
		if item != null and (item.item_class == item_class or item.item_class == ItemBase.ItemClass.ALL):
			result.append(item)

	return result


func roll_rarity() -> ItemBase.Rarity:
	var roll := randi_range(1, 100)
	var accumulated_chance := 0

	for rarity in [
		ItemBase.Rarity.COMMON,
		ItemBase.Rarity.UNCOMMON,
		ItemBase.Rarity.RARE,
		ItemBase.Rarity.EPIC,
		ItemBase.Rarity.LEGENDARY
	]:
		accumulated_chance += int(RARITY_CHANCES.get(rarity, 0))

		if roll <= accumulated_chance:
			return rarity

	push_error("ItemDatabase: as chances de raridade não totalizam 100%.")
	return ItemBase.Rarity.COMMON


func get_random_item_by_rarity(
	rarity: ItemBase.Rarity,
	item_class: ItemBase.ItemClass = ItemBase.ItemClass.MAGE
) -> ItemBase:
	var available_items := get_items_by_rarity(rarity, item_class)

	if available_items.is_empty():
		push_warning(
			"ItemDatabase: nenhum item cadastrado para a raridade %s."
			% ItemBase.Rarity.keys()[rarity]
		)
		return null

	var index := randi_range(0, available_items.size() - 1)
	return available_items[index]
