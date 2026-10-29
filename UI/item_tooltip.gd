
extends Panel
class_name ItemTooltip

var font = preload("res://Fonts/Pix32.ttf")

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var rarity_label: Label = $MarginContainer/VBoxContainer/RarityLabel
@onready var attributes_container: VBoxContainer = $MarginContainer/VBoxContainer/AttributesContainer
@onready var enchantments_label: Label = $MarginContainer/VBoxContainer/EnchantmentsLabel
@onready var enchantment_slots: HBoxContainer = $MarginContainer/VBoxContainer/EnchantmentSlots
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var value_label: Label = $MarginContainer/VBoxContainer/ValueLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelLabel

var current_item: ItemInstance


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	top_level = true

	for label in [
		name_label,
		level_label,
		rarity_label,
		enchantments_label,
		description_label,
		value_label,
	]:
		label.add_theme_font_override("font", font)

	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(180, 0)
	description_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	hide()


func show_item(item: ItemInstance, hero_level: int = -1, hero_id: String = "") -> void:
	if item == null or item.item_base == null:
		hide()
		return

	current_item = item
	
	name_label.show()
	rarity_label.show()
	attributes_container.show()

	for node in find_children("*", "HSeparator", true, false):
		node.show()

	var base: ItemBase = item.item_base

	name_label.text = base.item_name
	
	level_label.text = "Nível: %d" % item.item_level
	_update_level_label_color(item, hero_level)
	level_label.show()
	
	rarity_label.text = ItemBase.Rarity.keys()[item.generated_rarity]
	_clear_attributes()
	_clear_enchantment_slots()
	_add_class_requirement(item, hero_id)
	rarity_label.add_theme_color_override(
		"font_color",
		_get_rarity_color(item.generated_rarity)
	)
	# Descrição do item.
	description_label.text = base.description
	description_label.visible = not base.description.strip_edges().is_empty()

	value_label.text = "Valor: %d em ouro" % item.item_value
	value_label.show()
	# Conteúdo específico das gemas.
	if base.item_type == ItemBase.ItemType.GEM:
		_add_attribute(
			"Efeito",
			_get_gem_effect_name(item.gem_effect)
		)

		_add_attribute(
			"Valor",
			_get_gem_effect_value(item)
		)

		enchantments_label.hide()
		enchantment_slots.hide()
	else:
		enchantments_label.text = "ENCANTAMENTOS"
		enchantments_label.show()
		enchantment_slots.show()

		_add_attribute("Força", item.strength_bonus)
		_add_attribute("Agilidade", item.agility_bonus)
		_add_attribute("Inteligência", item.intelligence_bonus)
		_add_attribute("Vitalidade", item.vitality_bonus)
		_add_attribute("Mana máxima", item.max_mana_bonus)
		_add_attribute("Dano físico", item.physical_damage_bonus)
		_add_attribute("Dano mágico", item.magic_damage_bonus)
		_add_attribute("Poder mágico", item.magic_power_bonus)
		_add_attribute("Defesa", item.defense_bonus)

		_create_enchantment_slots(item.enchantment_slots)

	show()

	# Espera os controles recalcularem o tamanho do conteúdo.
	await get_tree().process_frame

	if not is_instance_valid(self) or current_item != item:
		return

	_fit_tooltip_to_content()
	_update_position()


func _fit_tooltip_to_content() -> void:
	var margin_container := $MarginContainer as MarginContainer
	var vbox := $MarginContainer/VBoxContainer as VBoxContainer

	# Recalcula o tamanho mínimo dos elementos internos.
	force_update_transform()
	margin_container.reset_size()
	vbox.reset_size()

	var minimum_size := margin_container.get_combined_minimum_size()

	# Acrescenta as margens internas ao tamanho necessário.
	custom_minimum_size = minimum_size
	reset_size()

	# Garante que o painel não fique menor que o conteúdo.
	size = Vector2(
		maxf(size.x, minimum_size.x),
		maxf(size.y, minimum_size.y)
	)


func hide_tooltip() -> void:
	current_item = null
	hide()


func _process(_delta: float) -> void:
	if visible:
		_update_position()


func _update_position() -> void:
	var mouse_position := get_global_mouse_position()
	var viewport_size := get_viewport_rect().size

	var tooltip_position := mouse_position + Vector2(18, 18)
	var tooltip_size := size

	if tooltip_position.x + tooltip_size.x > viewport_size.x:
		tooltip_position.x = mouse_position.x - tooltip_size.x - 18

	if tooltip_position.y + tooltip_size.y > viewport_size.y:
		tooltip_position.y = mouse_position.y - tooltip_size.y - 18

	# Evita que o painel ultrapasse as bordas superiores ou esquerdas.
	tooltip_position.x = maxf(tooltip_position.x, 0.0)
	tooltip_position.y = maxf(tooltip_position.y, 0.0)

	position = tooltip_position


func _clear_attributes() -> void:
	for child in attributes_container.get_children():
		attributes_container.remove_child(child)
		child.queue_free()


func _clear_enchantment_slots() -> void:
	for child in enchantment_slots.get_children():
		enchantment_slots.remove_child(child)
		child.queue_free()


func _add_attribute(attribute_name: String, value: Variant) -> void:
	# Oculta atributos numéricos zerados.
	if value is int or value is float:
		if is_zero_approx(float(value)):
			return

	var label := Label.new()
	label.text = "%s: %s" % [
		attribute_name,
		_format_bonus(value)
	]

	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 14)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	attributes_container.add_child(label)


func _format_bonus(value: Variant) -> String:
	if value is String:
		return value

	if value is float:
		if is_equal_approx(value, roundf(value)):
			return "%+d" % roundi(value)

		return "%+.1f" % value

	if value is int:
		return "%+d" % value

	return str(value)


func _create_enchantment_slots(amount: int) -> void:
	var slot_count := clampi(amount, 0, 2)

	for i in range(slot_count):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(42, 42)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enchantment_slots.add_child(slot)


func _get_gem_effect_name(effect: ItemBase.GemEffect) -> String:
	match effect:
		ItemBase.GemEffect.STRENGTH:
			return "Força"
		ItemBase.GemEffect.AGILITY:
			return "Agilidade"
		ItemBase.GemEffect.INTELLIGENCE:
			return "Inteligência"
		ItemBase.GemEffect.VITALITY:
			return "Vitalidade"
		ItemBase.GemEffect.MAX_MANA:
			return "Mana máxima"
		ItemBase.GemEffect.PHYSICAL_DAMAGE:
			return "Dano físico"
		ItemBase.GemEffect.MAGIC_DAMAGE:
			return "Dano mágico"
		ItemBase.GemEffect.DEFENSE:
			return "Defesa"
		ItemBase.GemEffect.MAGIC_POWER:
			return "Poder mágico"
		_:
			return "Nenhum"


func _get_gem_effect_value(item: ItemInstance) -> String:
	if item.gem_effect == ItemBase.GemEffect.MAGIC_POWER:
		return "%+.1f%%" % item.gem_effect_value

	return "%+d" % roundi(item.gem_effect_value)


func show_empty_equipment_slot(_slot_name: String) -> void:
	current_item = null

	name_label.hide()
	rarity_label.hide()
	attributes_container.hide()
	enchantments_label.hide()
	enchantment_slots.hide()
	value_label.hide()
	level_label.hide()
	# Oculta todas as Separator do tooltip
	for node in find_children("*", "HSeparator", true, false):
		node.hide()

	description_label.text = "Sem equipamento."
	description_label.show()
	
	show()

	await get_tree().process_frame

	if not is_instance_valid(self) or current_item != null:
		return

	_fit_tooltip_to_content()
	_update_position()

func _get_rarity_color(rarity: ItemBase.Rarity) -> Color:
	match rarity:
		ItemBase.Rarity.COMMON:
			return Color("#b8b8b8") # Cinza
		ItemBase.Rarity.UNCOMMON:
			return Color("#45d66b") # Verde
		ItemBase.Rarity.RARE:
			return Color("#409bff") # Azul
		ItemBase.Rarity.EPIC:
			return Color("#c15cff") # Roxo
		ItemBase.Rarity.LEGENDARY:
			return Color("#ffad32") # Laranja

	return Color.WHITE

func _update_level_label_color(item: ItemInstance, hero_level: int = -1) -> void:
	# Gemas não exigem nível para serem usadas.
	if item.item_base.item_type == ItemBase.ItemType.GEM:
		level_label.add_theme_color_override(
			"font_color",
			Color("#b8b8b8")
		)
		return

	# O Status informa o nível do herói que está sendo visualizado.
	# Mantém a busca antiga como fallback para chamadas sem nível explícito.
	if hero_level < 0:
		var current_scene := get_tree().current_scene

		if current_scene != null:
			var player = current_scene.find_child("Player", true, false)
			if player != null and player.get("character_stats") != null:
				hero_level = int(player.character_stats.level)

	if hero_level < 0:
		level_label.add_theme_color_override(
			"font_color",
			Color("#b8b8b8")
		)
		return

	if item.item_level > hero_level:
		# Vermelho: nível insuficiente para equipar.
		level_label.add_theme_color_override(
			"font_color",
			Color("#ff4040")
		)
	else:
		# Cinza: nível suficiente para equipar.
		level_label.add_theme_color_override(
			"font_color",
			Color("#b8b8b8")
		)


func _add_class_requirement(item: ItemInstance, hero_id: String) -> void:
	if item == null or item.item_base == null:
		return
	if item.item_base.item_type == ItemBase.ItemType.GEM:
		return

	var class_names := ["Mage", "Knight", "Archer"]
	var required_index := int(item.item_base.item_class)
	var required_name := class_names[clampi(required_index, 0, class_names.size() - 1)]
	var label := Label.new()
	label.text = "Classe: %s" % required_name
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 14)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var normalized_hero_id := CharacterSelectionData.normalize_hero_id(hero_id)
	if not normalized_hero_id.is_empty():
		var hero_class := -1
		match normalized_hero_id:
			"mage":
				hero_class = ItemBase.ItemClass.MAGE
			"knight":
				hero_class = ItemBase.ItemClass.KNIGHT
			"archer":
				hero_class = ItemBase.ItemClass.ARCHER
		if hero_class >= 0 and hero_class != required_index:
			label.add_theme_color_override("font_color", Color("#ff4040"))
		else:
			label.add_theme_color_override("font_color", Color("#b8b8b8"))
	else:
		label.add_theme_color_override("font_color", Color("#b8b8b8"))

	attributes_container.add_child(label)
