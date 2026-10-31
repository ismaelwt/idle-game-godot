extends Control
class_name EnchantmentScene

@onready var equipment_button: TextureButton = $Panel/Slot1/Equipament
@onready var gem_button: TextureButton = $Panel/Slot2/Gem
@onready var preview_button: TextureButton = $Panel/EnchantedItemSlot/EnchantedItem
@onready var description_label: Label = $Panel/Label3
@onready var gem_effect_label: Label = $Panel/GemEffectLabel
@onready var enchant_button: TextureButton = $Panel/EnchantButton

var inventory: Inventory
var selected_equipment: ItemInstance
var selected_gem: ItemInstance
var item_tooltip: ItemTooltip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enchant_button.pressed.connect(_on_enchant_pressed)
	equipment_button.mouse_entered.connect(_on_equipment_slot_mouse_entered)
	gem_button.mouse_entered.connect(_on_gem_slot_mouse_entered)
	preview_button.mouse_entered.connect(_on_equipment_slot_mouse_entered)
	equipment_button.mouse_exited.connect(_on_slot_mouse_exited)
	gem_button.mouse_exited.connect(_on_slot_mouse_exited)
	preview_button.mouse_exited.connect(_on_slot_mouse_exited)
	var scene := get_tree().current_scene
	if scene != null:
		item_tooltip = scene.find_child("ItemTooltip", true, false) as ItemTooltip
	_refresh_ui()


func setup(target_inventory: Inventory) -> void:
	inventory = target_inventory
	clear_selection()


func clear_selection() -> void:
	selected_equipment = null
	selected_gem = null
	_refresh_ui()


func select_item(item: ItemInstance) -> void:
	if item == null or item.item_base == null:
		return

	if item.item_base.item_type == ItemBase.ItemType.GEM:
		if selected_gem == item:
			return
		selected_gem = item
	else:
		if item.enchantment_slots <= item.installed_enchantments.size():
			description_label.text = "Este equipamento não possui slots livres."
			return
		selected_equipment = item

	_refresh_ui()


func _refresh_ui() -> void:
	if not is_node_ready():
		return

	_set_slot_icon(equipment_button, selected_equipment)
	_set_slot_icon(gem_button, selected_gem)
	_set_slot_icon(preview_button, selected_equipment)
	gem_effect_label.text = _get_gem_effect_description(selected_gem) if selected_gem != null else ""
	gem_effect_label.visible = selected_gem != null
	if selected_gem != null and selected_gem.item_base != null:
		gem_effect_label.add_theme_color_override("font_color", selected_gem.item_base.gem_color)

	var valid_selection := (
		is_instance_valid(inventory)
		and is_instance_valid(selected_equipment)
		and is_instance_valid(selected_gem)
		and selected_equipment.item_base != null
		and selected_gem.item_base != null
		and selected_gem.item_base.item_type == ItemBase.ItemType.GEM
		and selected_gem.gem_effect != ItemBase.GemEffect.NONE
		and selected_equipment.installed_enchantments.size() < selected_equipment.enchantment_slots
		and inventory.equipment.has(selected_gem)
		and (
			inventory.equipment.has(selected_equipment)
			or _is_equipped(selected_equipment)
		)
	)

	enchant_button.disabled = not valid_selection

	if selected_equipment == null and selected_gem == null:
		description_label.text = "Selecione um equipamento e uma gema no inventário."
	elif selected_equipment == null:
		description_label.text = "Gema selecionada: %s\nAgora selecione um equipamento." % selected_gem.item_base.item_name
	elif selected_gem == null:
		description_label.text = "Equipamento: %s\nSlots livres: %d\nAgora selecione uma gema." % [
			selected_equipment.item_base.item_name,
			selected_equipment.enchantment_slots - selected_equipment.installed_enchantments.size()
		]
	else:
		description_label.text = "%s\nGema: %s" % [
			selected_equipment.item_base.item_name,
			selected_gem.item_base.item_name
		]


func _set_slot_icon(button: TextureButton, item: ItemInstance) -> void:
	button.visible = item != null and item.item_base != null
	button.texture_normal = item.item_base.icon if button.visible else null
	button.texture_disabled = button.texture_normal
	button.tooltip_text = item.item_base.item_name if button.visible else ""



func _show_item_tooltip(item: ItemInstance) -> void:
	if not is_instance_valid(item_tooltip):
		var scene := get_tree().current_scene
		if scene != null:
			item_tooltip = scene.find_child("ItemTooltip", true, false) as ItemTooltip
	if not is_instance_valid(item_tooltip):
		return
	if item == null or item.item_base == null:
		item_tooltip.hide_tooltip()
		return
	item_tooltip.show_item(item)


func _on_equipment_slot_mouse_entered() -> void:
	_show_item_tooltip(selected_equipment)


func _on_gem_slot_mouse_entered() -> void:
	_show_item_tooltip(selected_gem)


func _on_slot_mouse_exited() -> void:
	if is_instance_valid(item_tooltip):
		item_tooltip.hide_tooltip()


func _is_equipped(item: ItemInstance) -> bool:
	if not is_instance_valid(inventory):
		return false
	for equipped in inventory.get_equipped_items(inventory.active_hero_id).values():
		if equipped == item:
			return true
	return false


func _get_gem_effect_description(gem: ItemInstance) -> String:
	var value := gem.gem_effect_value
	match gem.gem_effect:
		ItemBase.GemEffect.STRENGTH:
			return "Força +%d" % roundi(value)
		ItemBase.GemEffect.AGILITY:
			return "Agilidade +%d" % roundi(value)
		ItemBase.GemEffect.INTELLIGENCE:
			return "Inteligência +%d" % roundi(value)
		ItemBase.GemEffect.VITALITY:
			return "Vitalidade +%d" % roundi(value)
		ItemBase.GemEffect.MAX_MANA:
			return "Mana máxima +%d" % roundi(value)
		ItemBase.GemEffect.PHYSICAL_DAMAGE:
			return "Dano físico +%d" % roundi(value)
		ItemBase.GemEffect.MAGIC_DAMAGE:
			return "Dano mágico +%d" % roundi(value)
		ItemBase.GemEffect.DEFENSE:
			return "Defesa física e mágica +%d" % roundi(value)
		ItemBase.GemEffect.PHYSICAL_DEFENSE:
			return "Defesa física +%d" % roundi(value)
		ItemBase.GemEffect.MAGIC_DEFENSE:
			return "Defesa mágica +%d" % roundi(value)
		ItemBase.GemEffect.CRITICAL_CHANCE:
			return "Chance crítica +%.1f%%" % value
		ItemBase.GemEffect.CRITICAL_DAMAGE:
			return "Dano crítico +%.1f%%" % value
		ItemBase.GemEffect.MAGIC_POWER:
			return "Poder mágico +%.1f%%" % value
		ItemBase.GemEffect.LIFE_STEAL:
			return "Roubo de vida +%.1f%%" % value
		ItemBase.GemEffect.MANA_STEAL:
			return "Roubo de mana +%.1f%%" % value
	return "Efeito não definido"


func _on_enchant_pressed() -> void:
	if not is_instance_valid(inventory):
		return
	if not is_instance_valid(selected_equipment) or not is_instance_valid(selected_gem):
		return

	if inventory.install_gem(
		selected_equipment,
		selected_gem,
		inventory.active_hero_id
	):
		clear_selection()
