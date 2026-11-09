extends Control
class_name InventoryWindow

var font: Font = preload("res://Fonts/Pix32.ttf")
var item_tooltip_scene: PackedScene = preload("res://UI/item_tooltip.tscn")
var my_chest_scene: PackedScene = preload("res://Scenes/my_chest.tscn")

@onready var inventory_panel: Panel = $InventoryPanel
@onready var items_grid: GridContainer = $InventoryPanel/VBoxContainer/ScrollContainer/ItemsGrid
@onready var chest_button: TextureButton = $InventoryPanel/VBoxContainer/Header/ChestButton
@onready var chest_count_label: Label = $InventoryPanel/VBoxContainer/Header/Control/ChestCount
@onready var sell_all_button: TextureButton = $InventoryPanel/VBoxContainer/Header/SellAllButton
@onready var gold_label: Label = $InventoryPanel/VBoxContainer/Control/GoldLabel

var inventory: Inventory
var character_stats
var enchantment_ui: EnchantmentScene
var item_tooltip: ItemTooltip
var my_chest_ui: MyChest = null
var selected_equipment_for_gem: ItemInstance = null
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var setup_complete: bool = false


func _ready() -> void:
	# O Control raiz define toda a área que pode iniciar o arraste.
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 10


func setup(inventory_ref: Inventory, stats_ref, enchantment_ref: EnchantmentScene) -> void:
	inventory = inventory_ref
	character_stats = stats_ref
	enchantment_ui = enchantment_ref

	if inventory == null:
		push_error("InventoryWindow: nó Inventory não foi informado.")
		return

	if inventory.has_signal("inventory_changed"):
		if not inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.connect(_on_inventory_changed)

	chest_button.pressed.connect(_on_chest_pressed)
	sell_all_button.pressed.connect(_on_sell_all_pressed)

	_create_item_tooltip()
	create_inventory_slots(45)
	setup_complete = true
	set_character_stats(character_stats)
	refresh_inventory()


func _create_item_tooltip() -> void:
	item_tooltip = item_tooltip_scene.instantiate() as ItemTooltip
	if item_tooltip == null:
		push_error("InventoryWindow: não foi possível criar ItemTooltip.")
		return

	item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_tooltip.z_index = 4096
	item_tooltip.top_level = true

	var canvas_layer := _find_canvas_layer(self)
	if canvas_layer != null:
		canvas_layer.add_child.call_deferred(item_tooltip)
	else:
		get_tree().current_scene.add_child.call_deferred(item_tooltip)

	item_tooltip.hide()


func set_character_stats(stats_ref) -> void:
	character_stats = stats_ref
	selected_equipment_for_gem = null

	if is_instance_valid(inventory) and is_instance_valid(character_stats):
		inventory.active_hero_id = str(character_stats.hero_id)

	if setup_complete:
		refresh_inventory()


func set_enchantment_ui(enchantment_ref: EnchantmentScene) -> void:
	enchantment_ui = enchantment_ref


func select_equipment_for_gem(item: ItemInstance) -> void:
	selected_equipment_for_gem = item


func _process(_delta: float) -> void:
	if is_instance_valid(gold_label):
		var gold_text := "GOLD: (" + str(GameManager.gold) + ")"
		if gold_label.text != gold_text:
			gold_label.text = gold_text


func _input(event: InputEvent) -> void:
	# _input roda antes dos eventos GUI dos filhos, permitindo arrastar
	# mesmo quando o clique começa sobre o Panel ou outro filho.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if get_global_rect().has_point(event.position):
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
				move_to_front()
		else:
			dragging = false

	elif event is InputEventMouseMotion and dragging:
		var new_global_position := get_global_mouse_position() - drag_offset
		var viewport_size := get_viewport_rect().size
		var panel_offset := inventory_panel.position
		var min_position := -panel_offset
		var max_position := viewport_size - inventory_panel.size - panel_offset

		new_global_position.x = clampf(new_global_position.x, min_position.x, maxf(max_position.x, min_position.x))
		new_global_position.y = clampf(new_global_position.y, min_position.y, maxf(max_position.y, min_position.y))
		global_position = new_global_position


# ==========================================
# SLOTS E ATUALIZAÇÃO DO INVENTÁRIO
# ==========================================

func create_inventory_slots(amount: int = 10) -> void:
	for child in items_grid.get_children():
		child.queue_free()

	for i in range(amount):
		var slot := Panel.new()
		slot.name = "Slot_%02d" % (i + 1)
		slot.custom_minimum_size = Vector2(40, 40)
		items_grid.add_child(slot)

		var icon_rect := TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_rect)

		var item_button := Button.new()
		item_button.name = "ItemButton"
		item_button.flat = true
		item_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		item_button.mouse_filter = Control.MOUSE_FILTER_STOP
		item_button.tooltip_text = ""
		slot.add_child(item_button)

		item_button.gui_input.connect(_on_inventory_slot_gui_input.bind(i))
		item_button.mouse_exited.connect(_on_inventory_slot_mouse_exited)


func refresh_inventory() -> void:
	if inventory == null or items_grid == null:
		return

	chest_count_label.text = str(inventory.chest_count)
	chest_button.disabled = inventory.chest_count <= 0

	var backpack_items := inventory.get_backpack_items()
	var slots := items_grid.get_children()

	for i in range(slots.size()):
		var slot := slots[i] as Panel
		var icon_rect := slot.get_node("Icon") as TextureRect
		var item_button := slot.get_node("ItemButton") as Button

		icon_rect.texture = null
		icon_rect.show()
		_remove_animated_item_sprite(slot)
		set_tier_badge(slot, null)
		item_button.tooltip_text = ""

		if i < backpack_items.size():
			var item: ItemInstance = backpack_items[i]
			if item != null and item.item_base != null:
				var base = item.item_base
				if base.animated_frames != null:
					icon_rect.hide()
					_add_animated_item_sprite(slot, base.animated_frames)
				else:
					match item.enchantment_slots:
						1:
							icon_rect.texture = base.icon_slot_1 if base.icon_slot_1 != null else base.icon
						2:
							icon_rect.texture = base.icon_slot_2 if base.icon_slot_2 != null else base.icon
						_:
							icon_rect.texture = base.icon

				set_tier_badge(slot, item)


func set_tier_badge(parent: Control, item: ItemInstance) -> void:
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
	badge.add_theme_font_override("font", font)
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


func _on_inventory_changed() -> void:
	refresh_inventory()


# ==========================================
# AÇÕES DO INVENTÁRIO
# ==========================================

func toggle_my_chest() -> void:
	if not is_instance_valid(inventory) or not is_instance_valid(character_stats):
		return

	if is_instance_valid(my_chest_ui):
		my_chest_ui.queue_free()
		my_chest_ui = null
		return

	my_chest_ui = my_chest_scene.instantiate() as MyChest
	if my_chest_ui == null:
		push_error("InventoryWindow: não foi possível abrir a cena MyChest.")
		return

	var canvas_layer := _find_canvas_layer(self)
	if is_instance_valid(canvas_layer):
		canvas_layer.add_child(my_chest_ui)
	else:
		get_tree().current_scene.add_child(my_chest_ui)

	my_chest_ui.setup(inventory, item_tooltip, int(character_stats.level), str(character_stats.hero_id))


func _on_chest_pressed() -> void:
	if inventory == null or inventory.chest_count <= 0:
		return
	inventory.open_chest()


func _on_sell_all_pressed() -> void:
	if inventory == null:
		return

	if inventory.get_backpack_items().is_empty():
		print("A mochila está vazia.")
		return

	var total_value: int = inventory.sell_all_equipment()
	if total_value < 0:
		return

	if is_instance_valid(item_tooltip):
		item_tooltip.hide_tooltip()

	print("Venda concluída: ", total_value, " ouro.")


func _on_inventory_slot_pressed(index: int) -> void:
	if inventory == null or not is_instance_valid(character_stats):
		return

	var backpack_items := inventory.get_backpack_items()
	if index < 0 or index >= backpack_items.size():
		return

	var item: ItemInstance = backpack_items[index]
	if item == null or item.item_base == null:
		return

	if is_instance_valid(enchantment_ui) and enchantment_ui.visible:
		enchantment_ui.select_item(item)
		return

	if item.item_base.item_type == ItemBase.ItemType.GEM:
		if not is_instance_valid(selected_equipment_for_gem):
			print("Selecione primeiro um equipamento com slot de gema.")
			return

		if inventory.install_gem(selected_equipment_for_gem, item, str(character_stats.hero_id)):
			selected_equipment_for_gem = null
			if is_instance_valid(item_tooltip):
				item_tooltip.hide_tooltip()
		return

	inventory.equip_item(item, str(character_stats.hero_id))


func _on_inventory_slot_gui_input(event: InputEvent, index: int) -> void:
	if inventory == null or not is_instance_valid(character_stats):
		return

	var backpack_items := inventory.get_backpack_items()
	if index < 0 or index >= backpack_items.size():
		if is_instance_valid(item_tooltip):
			item_tooltip.hide_tooltip()
		return

	var item: ItemInstance = backpack_items[index]

	if event is InputEventMouseMotion:
		if is_instance_valid(item_tooltip) and item != null:
			item_tooltip.show_item(item, int(character_stats.level), str(character_stats.hero_id))

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_instance_valid(my_chest_ui):
				inventory.set_item_stored(item, true)
			else:
				_on_inventory_slot_pressed(index)

			if is_instance_valid(item_tooltip):
				item_tooltip.hide_tooltip()
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_instance_valid(item_tooltip):
				item_tooltip.hide_tooltip()
			get_viewport().set_input_as_handled()


func _on_inventory_slot_mouse_exited() -> void:
	if is_instance_valid(item_tooltip):
		item_tooltip.hide_tooltip()


func get_item_tooltip(item: ItemInstance) -> String:
	if item == null or item.item_base == null:
		return "Slot vazio"

	var base: ItemBase = item.item_base
	var rarity_name: String = ItemBase.Rarity.keys()[item.generated_rarity]
	var tooltip: String = "%s\n" % base.item_name
	tooltip += "Raridade: %s\n" % rarity_name
	tooltip += "--------------------\n"

	if base.item_type == ItemBase.ItemType.GEM:
		match item.gem_effect:
			ItemBase.GemEffect.STRENGTH:
				tooltip += "Força: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.AGILITY:
				tooltip += "Agilidade: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.INTELLIGENCE:
				tooltip += "Inteligência: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.VITALITY:
				tooltip += "Vitalidade: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.MAX_MANA:
				tooltip += "Mana máxima: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.PHYSICAL_DAMAGE:
				tooltip += "Dano físico: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.MAGIC_DAMAGE:
				tooltip += "Dano mágico: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.DEFENSE:
				tooltip += "Defesa física e mágica: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.PHYSICAL_DEFENSE:
				tooltip += "Defesa física: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.MAGIC_DEFENSE:
				tooltip += "Defesa mágica: %+d\n" % roundi(item.gem_effect_value)
			ItemBase.GemEffect.LIFE_STEAL:
				tooltip += "Roubo de vida por hit: +%.1f%%\n" % item.gem_effect_value
			ItemBase.GemEffect.MANA_STEAL:
				tooltip += "Roubo de mana por hit: +%.1f%%\n" % item.gem_effect_value
			ItemBase.GemEffect.MAGIC_POWER:
				tooltip += "Poder mágico: +%.1f%%\n" % item.gem_effect_value
			ItemBase.GemEffect.NONE:
				tooltip += "Sem efeito definido\n"

		tooltip += "Consumível/Encantamento"
		return tooltip

	tooltip += "Força: %+d\n" % item.strength_bonus
	tooltip += "Agilidade: %+d\n" % item.agility_bonus
	tooltip += "Inteligência: %+d\n" % item.intelligence_bonus
	tooltip += "Vitalidade: %+d\n" % item.vitality_bonus
	tooltip += "Dano físico: %+d\n" % item.physical_damage_bonus
	tooltip += "Dano mágico: %+d\n" % item.magic_damage_bonus
	tooltip += "Defesa física: %+d\n" % item.physical_defense_bonus
	tooltip += "Defesa mágica: %+d\n" % item.magic_defense_bonus
	tooltip += "Roubo de vida: %+.1f%%\n" % item.life_steal_bonus
	tooltip += "Roubo de mana: %+.1f%%\n" % item.mana_steal_bonus
	tooltip += "Encantamentos: %d" % item.enchantment_slots
	return tooltip


func _remove_animated_item_sprite(slot: Control) -> void:
	for child in slot.get_children():
		if child is AnimatedSprite2D:
			slot.remove_child(child)
			child.queue_free()


func _add_animated_item_sprite(slot: Control, frames: SpriteFrames) -> void:
	var animated_sprite := AnimatedSprite2D.new()
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = "default"
	animated_sprite.centered = true
	animated_sprite.position = Vector2(20, 20)
	animated_sprite.z_index = 2

	var first_frame := frames.get_frame_texture("default", 0)
	if first_frame != null:
		var frame_size := first_frame.get_size()
		if frame_size.x > 0.0 and frame_size.y > 0.0:
			var fit_scale := minf(34.0 / frame_size.x, 34.0 / frame_size.y)
			animated_sprite.scale = Vector2.ONE * fit_scale

	slot.add_child(animated_sprite)
	animated_sprite.play("default")


func _find_canvas_layer(node: Node) -> CanvasLayer:
	var parent := node.get_parent()
	while parent != null:
		if parent is CanvasLayer:
			return parent
		parent = parent.get_parent()
	return null


func cleanup() -> void:
	if is_instance_valid(item_tooltip):
		item_tooltip.hide_tooltip()
		item_tooltip.queue_free()
		item_tooltip = null

	if is_instance_valid(my_chest_ui):
		my_chest_ui.queue_free()
		my_chest_ui = null
