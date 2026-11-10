extends Control
class_name MyChest

const STORAGE_CAPACITY: int = 40
const SLOT_SIZE := Vector2(40, 40)
const ItemRarityVisualsScript = preload("res://Script/item_rarity_visuals.gd")

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
			if child.name == "RarityGlowBorder":
				continue
			child.queue_free()

		if index >= stored_items.size():
			slot.tooltip_text = ""
			ItemRarityVisualsScript.apply_to_slot(slot, null)
			continue

		var item: ItemInstance = stored_items[index]
		if item == null or item.item_base == null:
			ItemRarityVisualsScript.apply_to_slot(slot, null)
			continue

		slot.tooltip_text = "%s | Nível %d | %s" % [
			item.item_base.item_name,
			item.item_level,
			ItemBase.Rarity.keys()[item.generated_rarity]
		]
		if item.item_base.animated_frames != null:
			_add_animated_item_sprite(slot, item.item_base.animated_frames)
		else:
			var icon := TextureRect.new()
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.texture = _get_item_icon(item)
			slot.add_child(icon)
		ItemRarityVisualsScript.apply_to_slot(slot, item)
		_set_tier_badge(slot, item)


func _set_tier_badge(parent: Control, item: ItemInstance) -> void:
	var old_badge := parent.get_node_or_null("TierBadge")
	if is_instance_valid(old_badge):
		parent.remove_child(old_badge)
		old_badge.free()
	if item == null or item.tier <= 0:
		return
	var badge := Label.new()
	badge.name = "TierBadge"
	badge.text = "T%d" % item.tier
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font", preload("res://Fonts/Pix32.ttf"))
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color("#ffd45c"))
	badge.add_theme_color_override("font_outline_color", Color("#211800"))
	badge.add_theme_constant_override("outline_size", 3)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -22.0
	badge.offset_top = 1.0
	badge.offset_right = -1.0
	badge.offset_bottom = 17.0
	badge.z_index = 10
	parent.add_child(badge)


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


func _add_animated_item_sprite(slot: Control, frames: SpriteFrames) -> void:
	var animated_sprite := AnimatedSprite2D.new()
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = "default"
	animated_sprite.centered = true
	animated_sprite.position = SLOT_SIZE / 2.0
	animated_sprite.z_index = 2
	var first_frame := frames.get_frame_texture("default", 0)
	if first_frame != null:
		var frame_size := first_frame.get_size()
		if frame_size.x > 0.0 and frame_size.y > 0.0:
			var fit_scale := minf(34.0 / frame_size.x, 34.0 / frame_size.y)
			animated_sprite.scale = Vector2.ONE * fit_scale
	slot.add_child(animated_sprite)
	animated_sprite.play("default")
