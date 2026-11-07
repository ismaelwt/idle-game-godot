extends Control

var inventory: Inventory
var items_grid: GridContainer
var backpack_tab: Button
var storage_tab: Button
var close_button: Button
var showing_storage: bool = true


func _ready() -> void:
	items_grid = $ChestPanel/VBoxContainer/ScrollContainer/ItemsGrid
	_build_header_controls()
	_refresh_items()


func setup(source_inventory: Inventory) -> void:
	inventory = source_inventory
	if is_instance_valid(inventory) and not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
	if is_node_ready():
		_refresh_items()


func _exit_tree() -> void:
	if is_instance_valid(inventory) and inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.disconnect(_on_inventory_changed)


func _build_header_controls() -> void:
	var header: HBoxContainer = $ChestPanel/VBoxContainer/Header
	backpack_tab = Button.new()
	backpack_tab.text = "MOCHILA"
	backpack_tab.pressed.connect(_show_backpack)
	header.add_child(backpack_tab)

	storage_tab = Button.new()
	storage_tab.text = "ARMAZENAMENTO"
	storage_tab.pressed.connect(_show_storage)
	header.add_child(storage_tab)

	close_button = Button.new()
	close_button.text = "X"
	close_button.pressed.connect(queue_free)
	header.add_child(close_button)


func _show_backpack() -> void:
	showing_storage = false
	_refresh_items()


func _show_storage() -> void:
	showing_storage = true
	_refresh_items()


func _on_inventory_changed() -> void:
	_refresh_items()


func _refresh_items() -> void:
	if not is_instance_valid(items_grid) or not is_instance_valid(inventory):
		return

	for child in items_grid.get_children():
		child.queue_free()

	var visible_items: Array[ItemInstance] = (
		inventory.get_stored_items()
		if showing_storage
		else inventory.get_backpack_items()
	)

	for item in visible_items:
		_add_item_slot(item)

	if is_instance_valid(backpack_tab):
		backpack_tab.disabled = not showing_storage
	if is_instance_valid(storage_tab):
		storage_tab.disabled = showing_storage


func _add_item_slot(item: ItemInstance) -> void:
	if item == null or item.item_base == null:
		return

	var button := Button.new()
	button.custom_minimum_size = Vector2(40, 40)
	button.tooltip_text = "%s | Nível %d | %s" % [
		item.item_base.item_name,
		item.item_level,
		ItemBase.Rarity.keys()[item.generated_rarity]
	]
	button.pressed.connect(_toggle_item_storage.bind(item))
	items_grid.add_child(button)

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _get_item_icon(item)
	button.add_child(icon)


func _get_item_icon(item: ItemInstance) -> Texture2D:
	var base := item.item_base
	match item.enchantment_slots:
		1:
			return base.icon_slot_1 if base.icon_slot_1 != null else base.icon
		2:
			return base.icon_slot_2 if base.icon_slot_2 != null else base.icon
		_:
			return base.icon


func _toggle_item_storage(item: ItemInstance) -> void:
	if not is_instance_valid(inventory):
		return
	inventory.set_item_stored(item, not item.stored)
	_refresh_items()
