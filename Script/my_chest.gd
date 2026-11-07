extends Control

var inventory: Inventory
var shared_stash: SharedStash

var backpack_grid: GridContainer
var stash_grid: GridContainer


func _ready() -> void:
	_build_interface()


func setup(source_inventory: Inventory, source_stash: SharedStash) -> void:
	inventory = source_inventory
	shared_stash = source_stash
	if is_node_ready():
		_refresh_grids()
	else:
		call_deferred("_refresh_grids")
	if is_instance_valid(inventory) and not inventory.inventory_changed.is_connected(_refresh_grids):
		inventory.inventory_changed.connect(_refresh_grids)
	if is_instance_valid(shared_stash) and not shared_stash.stash_changed.is_connected(_refresh_grids):
		shared_stash.stash_changed.connect(_refresh_grids)


func _exit_tree() -> void:
	if is_instance_valid(inventory) and inventory.inventory_changed.is_connected(_refresh_grids):
		inventory.inventory_changed.disconnect(_refresh_grids)
	if is_instance_valid(shared_stash) and shared_stash.stash_changed.is_connected(_refresh_grids):
		shared_stash.stash_changed.disconnect(_refresh_grids)


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 470)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-380, -235)
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)

	var title := Label.new()
	title.text = "BAÚ DE ARMAZENAMENTO"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "FECHAR"
	close_button.pressed.connect(queue_free)
	header.add_child(close_button)

	var separator := HSeparator.new()
	outer.add_child(separator)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	outer.add_child(columns)

	var backpack_column := _create_column("MOCHILA")
	columns.add_child(backpack_column)
	backpack_grid = backpack_column.get_node("Scroll/Grid") as GridContainer

	var stash_column := _create_column("ARMAZENAMENTO")
	columns.add_child(stash_column)
	stash_grid = stash_column.get_node("Scroll/Grid") as GridContainer

	_refresh_grids()


func _create_column(column_title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = column_title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	return column


func _refresh_grids() -> void:
	if not is_instance_valid(inventory) or not is_instance_valid(shared_stash):
		return
	if not is_instance_valid(backpack_grid) or not is_instance_valid(stash_grid):
		return

	_clear_grid(backpack_grid)
	_clear_grid(stash_grid)

	for item in inventory.equipment:
		_add_item_button(backpack_grid, item, true)
	for item in shared_stash.items:
		_add_item_button(stash_grid, item, false)


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()


func _add_item_button(grid: GridContainer, item: ItemInstance, from_backpack: bool) -> void:
	if item == null or item.item_base == null:
		return

	var button := Button.new()
	button.custom_minimum_size = Vector2(76, 76)
	button.tooltip_text = "%s | Nível %d | %s" % [
		item.item_base.item_name,
		item.item_level,
		ItemBase.Rarity.keys()[item.generated_rarity]
	]
	button.pressed.connect(_on_item_selected.bind(item, from_backpack))
	grid.add_child(button)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base = item.item_base
	match item.enchantment_slots:
		1:
			icon.texture = base.icon_slot_1 if base.icon_slot_1 != null else base.icon
		2:
			icon.texture = base.icon_slot_2 if base.icon_slot_2 != null else base.icon
		_:
			icon.texture = base.icon
	content.add_child(icon)

	var name_label := Label.new()
	name_label.text = item.item_base.item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)


func _on_item_selected(item: ItemInstance, from_backpack: bool) -> void:
	if from_backpack:
		shared_stash.store_item(item, inventory)
	else:
		shared_stash.withdraw_item(item, inventory)
	_refresh_grids()
