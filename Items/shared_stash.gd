extends Node
class_name SharedStash

signal stash_changed

var items: Array[ItemInstance] = []


func store_item(item: ItemInstance, inventory: Inventory) -> bool:
	if item == null or inventory == null:
		return false
	var inventory_index := inventory.equipment.find(item)
	if inventory_index < 0:
		return false

	inventory.equipment.remove_at(inventory_index)
	items.append(item)
	stash_changed.emit()
	inventory.inventory_changed.emit()
	SaveManager.save_inventory(inventory)
	return true


func withdraw_item(item: ItemInstance, inventory: Inventory) -> bool:
	if item == null or inventory == null:
		return false
	var stash_index := items.find(item)
	if stash_index < 0:
		return false

	items.remove_at(stash_index)
	inventory.equipment.append(item)
	stash_changed.emit()
	inventory.inventory_changed.emit()
	SaveManager.save_inventory(inventory)
	return true
