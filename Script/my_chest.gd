extends Control
class_name MyChest

const STORAGE_CAPACITY: int = 40
const SLOT_SIZE := Vector2(40, 40)

var inventory: Inventory
var item_tooltip: ItemTooltip
var hero_level: int = -1
var hero_id: String = ""
var items_grid: GridContainer
@onready var close_button = $ChestPanel/Control/CloseButton
var item_slots: Array[Button] = []


func _ready() -> void:
	items_grid = $ChestPanel/VBoxContainer/ScrollContainer/ItemsGrid
	items_grid.columns = 5
	close_button.pressed.connect(queue_free)
	_build_storage_slots()
	_refresh_items()


func setup(
	source_inventory: Inventory,
	shared_tooltip: ItemTooltip,
	current_hero_level: int = -1,
	current_hero_id: String = ""
) -> void:
	inventory = source_inventory
	item_tooltip = shared_tooltip
	hero_level = current_hero_level
	hero_id = current_hero_id
	if is_instance_valid(inventory) and not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
	if is_node_ready():
		_refresh_items()


func _exit_tree() -> void:
	if is_instance_valid(inventory) and inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.disconnect(_on_inventory_changed)


func _build_storage_slots() -> void:
	for index in range(STORAGE_CAPACITY):
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.tooltip_text = ""
		slot.gui_input.connect(_on_slot_gui_input.bind(index))
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(index))
		slot.mouse_exited.connect(_on_slot_mouse_exited)
		items_grid.add_child(slot)
		item_slots.append(slot)

	_refresh_items()


func _on_inventory_changed() -> void:
	_refresh_items()


func _refresh_items() -> void:
	if not is_instance_valid(items_grid):
		return

	var stored_items: Array[ItemInstance] = []
	if is_instance_valid(inventory):
		stored_items = inventory.get_stored_items()

	for index in range(item_slots.size()):
		var slot := item_slots[index]
		for child in slot.get_children():
			child.queue_free()

		if index >= stored_items.size():
			slot.tooltip_text = ""
			continue

		var item: ItemInstance = stored_items[index]
		if item == null or item.item_base == null:
			continue

		slot.tooltip_text = "%s | Nível %d | %s" % [
			item.item_base.item_name,
			item.item_level,
			ItemBase.Rarity.keys()[item.generated_rarity]
		]
		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _get_item_icon(item)
		slot.add_child(icon)


func _on_slot_mouse_entered(index: int) -> void:
	if not is_instance_valid(inventory) or not is_instance_valid(item_tooltip):
		return
	var stored_items := inventory.get_stored_items()
	if index < 0 or index >= stored_items.size():
		return
	var item: ItemInstance = stored_items[index]
	item_tooltip.show_item(item, hero_level, hero_id)


func _on_slot_mouse_exited() -> void:
	if is_instance_valid(item_tooltip):
		item_tooltip.hide_tooltip()


func _get_item_icon(item: ItemInstance) -> Texture2D:
	var base := item.item_base
	match item.enchantment_slots:
		1:
			return base.icon_slot_1 if base.icon_slot_1 != null else base.icon
		2:
			return base.icon_slot_2 if base.icon_slot_2 != null else base.icon
		_:
			return base.icon


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	if not is_instance_valid(inventory):
		return

	var stored_items := inventory.get_stored_items()
	if index < 0 or index >= stored_items.size():
		return

	if is_instance_valid(item_tooltip):
		item_tooltip.hide_tooltip()
	inventory.set_item_stored(stored_items[index], false)
	get_viewport().set_input_as_handled()
