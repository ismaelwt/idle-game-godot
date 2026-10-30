
extends Panel

var font = preload("res://Fonts/Pix32.ttf")

var item_tooltip_scene = preload("res://UI/item_tooltip.tscn")
var item_tooltip: ItemTooltip


@onready var title_label = $CenterContainer/PanelContainer/VBoxContainer/Title
@onready var level_label = $CenterContainer/PanelContainer/VBoxContainer/Level
@onready var xp_label = $CenterContainer/PanelContainer/VBoxContainer/XP
@onready var health_label = $CenterContainer/PanelContainer/VBoxContainer/Health
@onready var mana_label = $CenterContainer/PanelContainer/VBoxContainer/Mana
@onready var damage_label = $CenterContainer/PanelContainer/VBoxContainer/Damage
@onready var attack_speed_label = $CenterContainer/PanelContainer/VBoxContainer/AttackSpeed
@onready var max_health_label = $CenterContainer/PanelContainer/VBoxContainer/MaxHealth
@onready var max_mana_label = $CenterContainer/PanelContainer/VBoxContainer/MaxMana

@onready var gold_label = $CenterContainer/InventoryControl/InventoryPanel/VBoxContainer/Control/GoldLabel
@onready var close_button = $CenterContainer/PanelContainer/Background/CloseButton

@onready var knight_change_button: TextureButton = $CenterContainer/PanelContainer/Background/KnightAvatar
@onready var mage_change_button: TextureButton = $CenterContainer/PanelContainer/Background/MageAvatar

@onready var knight_selected_icon: TextureRect = $CenterContainer/PanelContainer/Background/KnightAvatar/SelectedPlayer
@onready var mage_selected_icon: TextureRect = $CenterContainer/PanelContainer/Background/MageAvatar/SelectedPlayer

@onready var inventory_panel = $CenterContainer/InventoryControl/InventoryPanel
@onready var items_grid: GridContainer = $CenterContainer/InventoryControl/InventoryPanel/VBoxContainer/ScrollContainer/ItemsGrid
@onready var chest_button: TextureButton = $CenterContainer/InventoryControl/InventoryPanel/VBoxContainer/Header/ChestButton
@onready var chest_count_label: Label = $CenterContainer/InventoryControl/InventoryPanel/VBoxContainer/Header/Control/ChestCount
@onready var sell_all_button: TextureButton = $CenterContainer/InventoryControl/InventoryPanel/VBoxContainer/Header/SellAllButton
# ==========================================
# SLOTS DE EQUIPAMENTO
# ==========================================

@onready var helmet_icon: TextureRect = $CenterContainer/PanelContainer/Control/PlayerPanel/Helmet/Icon
@onready var chest_icon: TextureRect = $CenterContainer/PanelContainer/Control/PlayerPanel/Chest/Icon
@onready var weapon_icon: TextureRect = $CenterContainer/PanelContainer/Control/PlayerPanel/Weapon/Icon
@onready var gloves_icon: TextureRect = $CenterContainer/PanelContainer/Control/PlayerPanel/Gloves/Icon
@onready var pants_icon: TextureRect = $CenterContainer/PanelContainer/Control/PlayerPanel/Pants/Icon
@onready var boots_icon: TextureRect = $CenterContainer/PanelContainer/Control/PlayerPanel/Boots/Icon

# Atributos
@onready var available_points_label: Label = $CenterContainer/AttributesControl/PanelContainer/VBoxContainer/Points/AvailablePoints

@onready var strength_label: Label = $CenterContainer/AttributesControl/PanelContainer/VBoxContainer/Strength/StrengthPoints
@onready var strength_button: TextureButton = $CenterContainer/AttributesControl/PanelContainer/VBoxContainer/Strength/Add

@onready var agility_label: Label = $CenterContainer/AttributesControl/PanelContainer/VBoxContainer/Agility/AgilityPoints
@onready var agility_button: TextureButton = $CenterContainer/AttributesControl/PanelContainer/VBoxContainer/Agility/Add

@onready var intelligence_label: Label = $CenterContainer/AttributesControl/PanelContainer/VBoxContainer/Intelligence/IntelligencePoints
@onready var intelligence_button: TextureButton = $CenterContainer/AttributesControl/PanelContainer/VBoxContainer/Intelligence/Add

@onready var vitality_label: Label = $CenterContainer/AttributesControl/PanelContainer/VBoxContainer/Vitality/VitalityPoints
@onready var vitality_button: TextureButton = $CenterContainer/AttributesControl/PanelContainer/VBoxContainer/Vitality/Add

var helmet_default_icon: Texture2D
var chest_default_icon: Texture2D
var weapon_default_icon: Texture2D
var gloves_default_icon: Texture2D
var pants_default_icon: Texture2D
var boots_default_icon: Texture2D

var active_hero
var character_stats
var inventory: Inventory
var additional_status_labels: Dictionary = {}
var selected_equipment_for_gem: ItemInstance = null



func _ready() -> void:
	hide()
	title_label.text = "Status: ( " + str(CharacterSelectionData.selected_character.to_upper() + " )") 
	# Cria uma única instância do tooltip personalizado.
	item_tooltip = item_tooltip_scene.instantiate()
	item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_tooltip.z_index = 4096
	item_tooltip.top_level = true

	var canvas_layer := _find_canvas_layer(self)

	if canvas_layer != null:
		canvas_layer.add_child.call_deferred(item_tooltip)
	else:
		get_tree().current_scene.add_child.call_deferred(item_tooltip)

	item_tooltip.hide()

	#configurar_fonte_tooltips()

	# Guarda os ícones vazios ANTES de selecionar o herói e atualizar os slots.
	helmet_default_icon = helmet_icon.texture
	chest_default_icon = chest_icon.texture
	weapon_default_icon = weapon_icon.texture
	gloves_default_icon = gloves_icon.texture
	pants_default_icon = pants_icon.texture
	boots_default_icon = boots_icon.texture

	# O Status resolve o personagem por identidade, sem depender de grupos legados.
	# Primeiro tenta resolver o herói selecionado; o seletor externo também
	# pode atualizar a referência chamando set_selected_hero(hero).
	active_hero = _find_selected_hero()

	inventory = get_tree().current_scene.find_child("Inventory", true, false)

	if is_instance_valid(active_hero):
		set_selected_hero(active_hero)

	if inventory == null:
		push_error("Status: nó Inventory não encontrado.")
	else:
		if is_instance_valid(character_stats):
			inventory.active_hero_id = str(character_stats.hero_id)

		if inventory.has_signal("inventory_changed"):
			if not inventory.inventory_changed.is_connected(_on_inventory_changed):
				inventory.inventory_changed.connect(_on_inventory_changed)

		if inventory.has_signal("equipment_changed"):
			if not inventory.equipment_changed.is_connected(_on_equipment_changed):
				inventory.equipment_changed.connect(_on_equipment_changed)

	strength_button.pressed.connect(_on_strength_pressed)
	agility_button.pressed.connect(_on_agility_pressed)
	intelligence_button.pressed.connect(_on_intelligence_pressed)
	vitality_button.pressed.connect(_on_vitality_pressed)

	close_button.pressed.connect(_on_close_pressed)
	knight_change_button.pressed.connect(_on_knight_change_pressed)
	mage_change_button.pressed.connect(_on_mage_change_pressed)
	chest_button.pressed.connect(_on_chest_pressed)
	sell_all_button.pressed.connect(_on_sell_all_pressed)

	create_inventory_slots(45)
	_create_additional_status_labels()

	update_attributes()
	update_status()
	refresh_inventory()


	# Configura a interação dos slots de equipamento.
	helmet_icon.gui_input.connect(_on_helmet_icon_gui_input)
	chest_icon.gui_input.connect(_on_chest_icon_gui_input)
	weapon_icon.gui_input.connect(_on_weapon_icon_gui_input)
	gloves_icon.gui_input.connect(_on_gloves_icon_gui_input)
	pants_icon.gui_input.connect(_on_pants_icon_gui_input)
	boots_icon.gui_input.connect(_on_boots_icon_gui_input)

	# Fecha o tooltip ao sair de cada slot.
	helmet_icon.mouse_exited.connect(_on_equipment_icon_mouse_exited)
	chest_icon.mouse_exited.connect(_on_equipment_icon_mouse_exited)
	weapon_icon.mouse_exited.connect(_on_equipment_icon_mouse_exited)
	gloves_icon.mouse_exited.connect(_on_equipment_icon_mouse_exited)
	pants_icon.mouse_exited.connect(_on_equipment_icon_mouse_exited)
	boots_icon.mouse_exited.connect(_on_equipment_icon_mouse_exited)

	# Permite que os ícones recebam os eventos do mouse.
	helmet_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	chest_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	gloves_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	pants_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	boots_icon.mouse_filter = Control.MOUSE_FILTER_STOP

	refresh_equipment_slots()
	_refresh_hero_switch_buttons()


func configurar_fonte_tooltips() -> void:
	var tooltip_theme := Theme.new()

	tooltip_theme.set_font("font", "TooltipLabel", font)
	tooltip_theme.set_font_size("font_size", "TooltipLabel", 16)
	tooltip_theme.set_color("font_color", "TooltipLabel", Color.WHITE)

	theme = tooltip_theme


func _process(_delta: float) -> void:
	if not is_instance_valid(active_hero):
		return

	if not is_instance_valid(character_stats):
		return

	# Vida e mana continuam sendo verificadas em tempo real.
	# Os textos só são atribuídos quando o conteúdo realmente muda.
	update_status()


# ==========================================
# STATUS DO PERSONAGEM
# ==========================================

func _set_label_text(label: Label, new_text: String) -> void:
	if label != null and label.text != new_text:
		label.text = new_text


func update_status() -> void:
	if not is_instance_valid(active_hero):
		return

	if not is_instance_valid(character_stats):
		return

	_set_label_text(level_label, "LEVEL: " + str(character_stats.level))

	_set_label_text(
		xp_label,
		"XP: " + str(character_stats.xp)
		+ " / " + str(character_stats.xp_to_next_level)
	)

	_set_label_text(
		health_label,
		"HEALTH: " + str(int(active_hero.health))
		+ " / " + str(int(active_hero.max_health))
	)

	_set_label_text(
		mana_label,
		"MANA: " + str(int(character_stats.mana))
		+ " / " + str(int(character_stats.max_mana))
	)

	var displayed_damage: float
	if _has_property(active_hero, "attack_damage"):
		displayed_damage = float(active_hero.get("attack_damage")) + character_stats.get_physical_damage_bonus()
	else:
		displayed_damage = float(active_hero.get("basic_attack_damage")) + character_stats.basic_attack_level + character_stats.get_magic_bonus()
	_set_label_text(damage_label, "DAMAGE: " + str(snappedf(displayed_damage, 0.1)))

	_set_label_text(
		attack_speed_label,
		"ATTACK SPEED: " + str(snapped(_get_display_attack_speed(), 0.01))
	)
	_set_label_text(max_health_label, "MAX HEALTH: " + str(int(active_hero.max_health)))
	_set_label_text(max_mana_label, "MAX MANA: " + str(int(character_stats.max_mana)))

	_set_additional_status("physical_damage", "PHYSICAL DAMAGE BONUS: %.1f" % character_stats.get_physical_damage_bonus())
	_set_additional_status("magic_damage", "MAGIC DAMAGE BONUS: %.1f" % character_stats.get_magic_bonus())
	_set_additional_status("physical_defense", "PHYSICAL DEFENSE: %.1f" % character_stats.get_equipment_bonus("physical_defense"))
	_set_additional_status("magic_defense", "MAGIC DEFENSE: %.1f" % character_stats.get_equipment_bonus("magic_defense"))
	_set_additional_status("critical_chance", "CRITICAL CHANCE: %.1f%%" % character_stats.get_critical_chance())
	_set_additional_status("critical_damage", "CRITICAL DAMAGE: %.0f%%" % (character_stats.CRITICAL_DAMAGE_MULTIPLIER * 100.0))
	_set_additional_status("life_steal", "LIFE STEAL PER HIT: %.1f%%" % character_stats.get_life_steal())
	_set_additional_status("mana_steal", "MANA STEAL PER HIT: %.1f%%" % character_stats.get_mana_steal())
	_set_additional_status("mana_regeneration", "MANA REGENERATION: %.1f / %.1fs" % [character_stats.get_mana_regeneration(), character_stats.mana_regen_interval])
	_set_additional_status("magic_power", "MAGIC POWER: %.1f%%" % character_stats.get_equipment_bonus("magic_power"))


func _create_additional_status_labels() -> void:
	var container := $CenterContainer/PanelContainer/VBoxContainer as VBoxContainer
	var entries := [
		"physical_damage", "magic_damage", "physical_defense", "magic_defense", "critical_chance",
		"critical_damage", "life_steal", "mana_steal",
		"mana_regeneration", "magic_power"
	]
	for key in entries:
		var label := Label.new()
		label.name = "Extra_" + str(key)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 14)
		container.add_child(label)
		additional_status_labels[key] = label


func _set_additional_status(key: String, value: String) -> void:
	var label: Label = additional_status_labels.get(key)
	_set_label_text(label, value)


func _get_display_attack_speed() -> float:
	# Exibe ataques por segundo usando o intervalo configurado de cada classe
	# e o multiplicador de velocidade derivado da Agilidade total.
	if not is_instance_valid(active_hero):
		return 0.0

	var interval_multiplier: float = float(character_stats.get_basic_attack_interval_multiplier())

	if _has_property(active_hero, "attack_base_duration"):
		var duration := float(active_hero.get("attack_base_duration"))
		if duration > 0.0:
			return 1.0 / (duration * interval_multiplier)

	if _has_property(active_hero, "attack_cooldown"):
		var cooldown := float(active_hero.get("attack_cooldown"))
		if cooldown > 0.0:
			return 1.0 / (cooldown * interval_multiplier)

	return 0.0


func _has_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false


func _on_inventory_changed() -> void:
	refresh_inventory()


func _on_equipment_changed() -> void:
	refresh_equipment_slots()
	update_attributes()
	update_status()


func _on_attributes_changed() -> void:
	update_attributes()
	update_status()


# ==========================================
# CRIAR SLOTS DO INVENTÁRIO
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

		# Desativa o tooltip nativo do Godot.
		item_button.tooltip_text = ""

		slot.add_child(item_button)

		item_button.gui_input.connect(
			_on_inventory_slot_gui_input.bind(i)
		)

		item_button.mouse_exited.connect(
			_on_inventory_slot_mouse_exited
		)


# ==========================================
# ATUALIZAR INVENTÁRIO
# ==========================================

func refresh_inventory() -> void:
	if inventory == null or items_grid == null:
		return

	chest_count_label.text = str(inventory.chest_count)
	chest_button.disabled = inventory.chest_count <= 0
	_set_label_text(gold_label, "GOLD: (" + str(GameManager.gold) + ")") 

	var slots := items_grid.get_children()

	for i in range(slots.size()):
		var slot := slots[i] as Panel
		var icon_rect := slot.get_node("Icon") as TextureRect
		var item_button := slot.get_node("ItemButton") as Button

		icon_rect.texture = null

		# Não utilizar tooltips nativos.
		item_button.tooltip_text = ""

		if i < inventory.equipment.size():
			var item: ItemInstance = inventory.equipment[i]

			if item != null and item.item_base != null:
				var base = item.item_base

				match item.enchantment_slots:
					1:
						icon_rect.texture = (
							base.icon_slot_1
							if base.icon_slot_1 != null
							else base.icon
						)
					2:
						icon_rect.texture = (
							base.icon_slot_2
							if base.icon_slot_2 != null
							else base.icon
						)
					_:
						icon_rect.texture = base.icon


func _on_chest_pressed() -> void:
	if inventory == null or inventory.chest_count <= 0:
		return

	inventory.open_chest()


func _on_item_pressed(item: ItemInstance) -> void:
	if item == null or item.item_base == null:
		return

	print("=== EQUIPAMENTO SELECIONADO ===")
	print("Nome: ", item.item_base.item_name)
	print("Raridade: ", ItemBase.Rarity.keys()[item.generated_rarity])
	print("Força: ", item.strength_bonus)
	print("Agilidade: ", item.agility_bonus)
	print("Inteligência: ", item.intelligence_bonus)
	print("Vitalidade: ", item.vitality_bonus)
	print("Dano físico: ", item.physical_damage_bonus)
	print("Dano mágico: ", item.magic_damage_bonus)
	print("Defesa física: ", item.physical_defense_bonus)
	print("Defesa mágica: ", item.magic_defense_bonus)
	print("Roubo de vida por hit: ", item.life_steal_bonus, "%")
	print("Roubo de mana por hit: ", item.mana_steal_bonus, "%")


func _on_close_pressed() -> void:
	if item_tooltip != null:
		item_tooltip.hide_tooltip()

	hide()


# ==========================================
# DESCRIÇÃO LEGADA DOS ITENS
# Mantida para compatibilidade com o projeto.
# Não é utilizada pelos tooltips visuais.
# ==========================================

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


# ==========================================
# EQUIPAR ITEM PELO INVENTÁRIO
# ==========================================

func _on_inventory_slot_pressed(index: int) -> void:
	if inventory == null:
		return
	if index < 0 or index >= inventory.equipment.size():
		return

	var item: ItemInstance = inventory.equipment[index]
	if item == null or item.item_base == null:
		return

	if item.item_base.item_type == ItemBase.ItemType.GEM:
		if not is_instance_valid(selected_equipment_for_gem):
			print("Selecione primeiro um equipamento com slot de gema.")
			return
		if inventory.install_gem(selected_equipment_for_gem, item, str(character_stats.hero_id)):
			selected_equipment_for_gem = null
			if item_tooltip != null:
				item_tooltip.hide_tooltip()
		return

	inventory.equip_item(item, str(character_stats.hero_id))


func _on_inventory_slot_gui_input(event: InputEvent, index: int) -> void:
	if inventory == null:
		return

	if index < 0 or index >= inventory.equipment.size():
		if item_tooltip != null:
			item_tooltip.hide_tooltip()
		return

	var item: ItemInstance = inventory.equipment[index]

	if event is InputEventMouseMotion:
		if item_tooltip != null and item != null:
			item_tooltip.show_item(item, int(character_stats.level), str(character_stats.hero_id))

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_on_inventory_slot_pressed(index)

			if item_tooltip != null:
				item_tooltip.hide_tooltip()

			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if item_tooltip != null:
				item_tooltip.hide_tooltip()

			get_viewport().set_input_as_handled()


func _on_inventory_slot_mouse_exited() -> void:
	if item_tooltip != null:
		item_tooltip.hide_tooltip()


# ==========================================
# ATUALIZAR TODOS OS SLOTS DE EQUIPAMENTO
# ==========================================

func refresh_equipment_slots() -> void:
	if inventory == null:
		return

	var helmet: ItemInstance = inventory.get_equipped_items(str(character_stats.hero_id)).get(
		ItemBase.ItemType.HELMET
	)

	if helmet != null and helmet.item_base != null:
		helmet_icon.texture = get_equipment_icon(helmet, helmet.item_base.icon)
	else:
		helmet_icon.texture = helmet_default_icon

	update_helmet_tooltip()

	var chest: ItemInstance = inventory.get_equipped_items(str(character_stats.hero_id)).get(
		ItemBase.ItemType.CHEST
	)

	if chest != null and chest.item_base != null:
		chest_icon.texture = get_equipment_icon(chest, chest.item_base.icon)
	else:
		chest_icon.texture = chest_default_icon

	update_chest_tooltip()

	var weapon: ItemInstance = inventory.get_equipped_items(str(character_stats.hero_id)).get(
		ItemBase.ItemType.WEAPON
	)

	if weapon != null and weapon.item_base != null:
		weapon_icon.texture = get_equipment_icon(weapon, weapon.item_base.icon)
	else:
		weapon_icon.texture = weapon_default_icon

	update_weapon_tooltip()

	var gloves: ItemInstance = inventory.get_equipped_items(str(character_stats.hero_id)).get(
		ItemBase.ItemType.GLOVES
	)

	if gloves != null and gloves.item_base != null:
		gloves_icon.texture = get_equipment_icon(gloves, gloves.item_base.icon)
	else:
		gloves_icon.texture = gloves_default_icon

	update_gloves_tooltip()

	var pants: ItemInstance = inventory.get_equipped_items(str(character_stats.hero_id)).get(
		ItemBase.ItemType.PANTS
	)

	if pants != null and pants.item_base != null:
		pants_icon.texture = get_equipment_icon(pants, pants.item_base.icon)
	else:
		pants_icon.texture = pants_default_icon

	update_pants_tooltip()

	var boots: ItemInstance = inventory.get_equipped_items(str(character_stats.hero_id)).get(
		ItemBase.ItemType.BOOTS
	)

	if boots != null and boots.item_base != null:
		boots_icon.texture = get_equipment_icon(boots, boots.item_base.icon)
	else:
		boots_icon.texture = boots_default_icon

	update_boots_tooltip()


# ==========================================
# ESCOLHER ÍCONE CONFORME ENCANTAMENTOS
# ==========================================

func get_equipment_icon(
	item: ItemInstance,
	default_icon: Texture2D
) -> Texture2D:
	if item == null or item.item_base == null:
		return default_icon

	var base = item.item_base

	if item.enchantment_slots >= 2 and base.icon_slot_2 != null:
		return base.icon_slot_2

	if item.enchantment_slots >= 1 and base.icon_slot_1 != null:
		return base.icon_slot_1

	return base.icon


# ==========================================
# TOOLTIP PERSONALIZADO DOS EQUIPAMENTOS
# ==========================================
func _handle_equipment_tooltip(
	event: InputEvent,
	item_type: int
) -> void:
	if not is_instance_valid(inventory):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var selected_hero_id := _get_valid_active_hero_id()
			if selected_hero_id.is_empty():
				return
			var selected_item: ItemInstance = inventory.get_equipped_items(selected_hero_id).get(item_type)
			if selected_item != null and selected_item.item_base != null and selected_item.enchantment_slots > selected_item.installed_enchantments.size():
				selected_equipment_for_gem = selected_item
				print("Equipamento selecionado para gema: ", selected_item.item_base.item_name)
				get_viewport().set_input_as_handled()
			return

	if not event is InputEventMouseMotion:
		return

	if not is_instance_valid(item_tooltip):
		return

	var hero_id := _get_valid_active_hero_id()

	if hero_id.is_empty():
		item_tooltip.hide_tooltip()
		return

	var equipped_items: Dictionary = inventory.get_equipped_items(hero_id)
	var item: ItemInstance = equipped_items.get(item_type)

	if item != null and is_instance_valid(item) and item.item_base != null:
		item_tooltip.show_item(item, int(character_stats.level), str(character_stats.hero_id))
	else:
		var slot_name := ""

		match item_type:
			ItemBase.ItemType.HELMET:
				slot_name = "Capacete"
			ItemBase.ItemType.CHEST:
				slot_name = "Peitoral"
			ItemBase.ItemType.WEAPON:
				slot_name = "Arma"
			ItemBase.ItemType.GLOVES:
				slot_name = "Luvas"
			ItemBase.ItemType.PANTS:
				slot_name = "Calças"
			ItemBase.ItemType.BOOTS:
				slot_name = "Botas"

		item_tooltip.show_empty_equipment_slot(slot_name)


func _on_equipment_icon_mouse_exited() -> void:
	if item_tooltip != null:
		item_tooltip.hide_tooltip()


# Os métodos abaixo desativam o tooltip nativo.
# O tooltip personalizado é acionado pelo movimento do mouse.

func update_helmet_tooltip() -> void:
	helmet_icon.tooltip_text = ""


func update_chest_tooltip() -> void:
	chest_icon.tooltip_text = ""


func update_weapon_tooltip() -> void:
	weapon_icon.tooltip_text = ""


func update_gloves_tooltip() -> void:
	gloves_icon.tooltip_text = ""


func update_pants_tooltip() -> void:
	pants_icon.tooltip_text = ""


func update_boots_tooltip() -> void:
	boots_icon.tooltip_text = ""


# ==========================================
# RETIRAR EQUIPAMENTOS COM BOTÃO DIREITO
# ==========================================

func _on_helmet_icon_gui_input(event: InputEvent) -> void:
	_handle_equipment_tooltip(event, ItemBase.ItemType.HELMET)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var hero_id := _get_valid_active_hero_id()

			if hero_id.is_empty() or not is_instance_valid(inventory):
				return

			inventory.unequip_item(ItemBase.ItemType.HELMET, hero_id)

			if item_tooltip != null:
				item_tooltip.hide_tooltip()

			get_viewport().set_input_as_handled()


func _on_chest_icon_gui_input(event: InputEvent) -> void:
	_handle_equipment_tooltip(event, ItemBase.ItemType.CHEST)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var hero_id := _get_valid_active_hero_id()

			if hero_id.is_empty() or not is_instance_valid(inventory):
				return

			inventory.unequip_item(ItemBase.ItemType.CHEST, hero_id)

			if item_tooltip != null:
				item_tooltip.hide_tooltip()

			get_viewport().set_input_as_handled()


func _on_weapon_icon_gui_input(event: InputEvent) -> void:
	_handle_equipment_tooltip(event, ItemBase.ItemType.WEAPON)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var hero_id := _get_valid_active_hero_id()

			if hero_id.is_empty() or not is_instance_valid(inventory):
				return

			inventory.unequip_item(ItemBase.ItemType.WEAPON, hero_id)

			if item_tooltip != null:
				item_tooltip.hide_tooltip()

			get_viewport().set_input_as_handled()


func _on_gloves_icon_gui_input(event: InputEvent) -> void:
	_handle_equipment_tooltip(event, ItemBase.ItemType.GLOVES)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var hero_id := _get_valid_active_hero_id()

			if hero_id.is_empty() or not is_instance_valid(inventory):
				return

			inventory.unequip_item(ItemBase.ItemType.GLOVES, hero_id)

			if item_tooltip != null:
				item_tooltip.hide_tooltip()

			get_viewport().set_input_as_handled()


func _on_pants_icon_gui_input(event: InputEvent) -> void:
	_handle_equipment_tooltip(event, ItemBase.ItemType.PANTS)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var hero_id := _get_valid_active_hero_id()

			if hero_id.is_empty() or not is_instance_valid(inventory):
				return

			inventory.unequip_item(ItemBase.ItemType.PANTS, hero_id)

			if item_tooltip != null:
				item_tooltip.hide_tooltip()

			get_viewport().set_input_as_handled()


func _on_boots_icon_gui_input(event: InputEvent) -> void:
	_handle_equipment_tooltip(event, ItemBase.ItemType.BOOTS)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var hero_id := _get_valid_active_hero_id()

			if hero_id.is_empty() or not is_instance_valid(inventory):
				return

			inventory.unequip_item(ItemBase.ItemType.BOOTS, hero_id)

			if item_tooltip != null:
				item_tooltip.hide_tooltip()

			get_viewport().set_input_as_handled()

func _find_canvas_layer(node: Node) -> CanvasLayer:
	var parent := node.get_parent()

	while parent != null:
		if parent is CanvasLayer:
			return parent

		parent = parent.get_parent()

	return null

func _on_sell_all_pressed() -> void:
	if inventory == null:
		return

	if inventory.equipment.is_empty():
		print("A mochila está vazia.")
		return

	var total_value: int = inventory.sell_all_equipment()

	if total_value < 0:
		return

	if item_tooltip != null:
		item_tooltip.hide_tooltip()

	print("Venda concluída: ", total_value, " ouro.")

func _on_level_up():
	update_attributes()
	update_status()


func update_attributes():
	if not character_stats:
		return

	_set_label_text(available_points_label, "(" + str(character_stats.attribute_points) + ")")
	_set_label_text(strength_label, "(" + str(character_stats.get_total_strength()) + ")")
	_set_label_text(agility_label, "(" + str(character_stats.get_total_agility()) + ")")
	_set_label_text(intelligence_label, "(" + str(character_stats.get_total_intelligence()) + ")")
	_set_label_text(vitality_label, "(" + str(character_stats.get_total_vitality()) + ")")


func _on_strength_pressed():
	if not character_stats:
		return
	character_stats.add_attribute_point("strength")
	SaveManager.save_character(character_stats, inventory, str(character_stats.hero_id))
	update_attributes()
	update_status()


func _on_agility_pressed():
	if not character_stats:
		return
	character_stats.add_attribute_point("agility")
	SaveManager.save_character(character_stats, inventory, str(character_stats.hero_id))
	update_attributes()
	update_status()


func _on_intelligence_pressed():
	if not character_stats:
		return
	character_stats.add_attribute_point("intelligence")
	SaveManager.save_character(character_stats, inventory, str(character_stats.hero_id))
	update_attributes()
	update_status()


func _on_vitality_pressed():
	if not character_stats:
		return
	character_stats.add_attribute_point("vitality")
	SaveManager.save_character(character_stats, inventory, str(character_stats.hero_id))
	update_attributes()
	update_status()


# Troca apenas o herói exibido na janela Status; não altera o herói principal
# da equipe nem a seleção usada pelo combate.
func _on_knight_change_pressed() -> void:
	_select_hero_by_id("knight")


func _on_mage_change_pressed() -> void:
	_select_hero_by_id("mage")


func _select_hero_by_id(hero_id: String) -> void:
	var hero := _find_hero_by_id(hero_id)
	if not is_instance_valid(hero):
		push_warning("Status: o herói '%s' não está disponível na equipe." % hero_id)
		_refresh_hero_switch_buttons()
		return

	set_selected_hero(hero)


func _find_hero_by_id(hero_id: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null

	# Preferir os heróis registrados no PartyManager, pois isso também
	# respeita a disponibilidade real do companheiro.
	var manager := scene.find_child("PartyManager", true, false) as PartyManager
	if is_instance_valid(manager):
		for hero in manager.get_heroes():
			if not is_instance_valid(hero):
				continue
			var stats := _get_hero_stats(hero)
			if is_instance_valid(stats):
				var current_id := str(stats.get("hero_id")).strip_edges().to_lower()
				if current_id == hero_id:
					return hero

	# Fallback para heróis registrados no grupo comum.
	for hero in get_tree().get_nodes_in_group("party_heroes"):
		if not is_instance_valid(hero):
			continue
		var stats := _get_hero_stats(hero)
		if is_instance_valid(stats):
			var current_id := str(stats.get("hero_id")).strip_edges().to_lower()
			if current_id == hero_id:
				return hero

	return null


func _get_hero_stats(hero: Node) -> Node:
	if not is_instance_valid(hero):
		return null
	var stats = hero.get("character_stats")
	if is_instance_valid(stats):
		return stats
	stats = hero.get_node_or_null("CharacterStats")
	if not is_instance_valid(stats):
		stats = hero.find_child("CharacterStats", true, false)
	return stats


func _refresh_hero_switch_buttons() -> void:
	if not is_instance_valid(knight_change_button):
		return

	if not is_instance_valid(mage_change_button):
		return

	# Mantém os botões habilitados apenas para heróis disponíveis.
	knight_change_button.disabled = not is_instance_valid(
		_find_hero_by_id("knight")
	)

	mage_change_button.disabled = not is_instance_valid(
		_find_hero_by_id("mage")
	)

	# Identifica o herói atualmente exibido no Status.
	var current_hero_id := ""

	if is_instance_valid(character_stats):
		current_hero_id = str(
			character_stats.get("hero_id")
		).strip_edges().to_lower()

	# Mostra o indicador somente ao lado do herói ativo no Status.
	if is_instance_valid(knight_selected_icon):
		knight_selected_icon.visible = (
			current_hero_id == "knight"
		)

	if is_instance_valid(mage_selected_icon):
		mage_selected_icon.visible = (
			current_hero_id == "mage"
		)
	

# Localiza heróis pela identidade do CharacterStats, sem depender do nome do nó.
func _find_selected_hero() -> Node:
	var selected_id := CharacterSelectionData.get_selected_character_id()
	return _find_hero_by_id(selected_id)


# Permite que um seletor de party externo altere o herói exibido sem duplicar a UI.
func set_selected_hero(hero: Node) -> void:
	if not is_instance_valid(hero):
		return

	selected_equipment_for_gem = null
	var new_stats = hero.get("character_stats")
	if not is_instance_valid(new_stats):
		return

	if is_instance_valid(character_stats):
		if character_stats.attributes_changed.is_connected(_on_attributes_changed):
			character_stats.attributes_changed.disconnect(_on_attributes_changed)
		if character_stats.level_up_occurred.is_connected(_on_level_up):
			character_stats.level_up_occurred.disconnect(_on_level_up)

	active_hero = hero
	character_stats = new_stats

	var hero_id := str(character_stats.get("hero_id")).strip_edges().to_lower()
	_set_label_text(title_label, "STATUS: ( " + hero_id.to_upper() + " )")

	if is_instance_valid(inventory):
		inventory.active_hero_id = str(character_stats.hero_id)

	if character_stats.has_signal("attributes_changed"):
		if not character_stats.attributes_changed.is_connected(_on_attributes_changed):
			character_stats.attributes_changed.connect(_on_attributes_changed)

	if character_stats.has_signal("level_up_occurred"):
		if not character_stats.level_up_occurred.is_connected(_on_level_up):
			character_stats.level_up_occurred.connect(_on_level_up)

	update_status()
	update_attributes()
	refresh_equipment_slots()
	refresh_inventory()
	_refresh_hero_switch_buttons()

func _get_valid_active_hero_id() -> String:
	if not is_instance_valid(active_hero):
		return ""

	var stats = active_hero.get("character_stats")

	if not is_instance_valid(stats):
		stats = active_hero.get_node_or_null("CharacterStats")

	if not is_instance_valid(stats):
		return ""

	character_stats = stats
	return str(stats.get("hero_id"))
