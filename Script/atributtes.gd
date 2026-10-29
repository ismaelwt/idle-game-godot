extends Panel


var character_stats


@onready var points_label = $CenterContainer/PanelContainer/VBoxContainer/Points/AvailablePoints

@onready var close_button = $CenterContainer/PanelContainer/VBoxContainer/CloseButton


@onready var strength_label = $CenterContainer/PanelContainer/VBoxContainer/Strength/StrengthPoints
@onready var strength_button = $CenterContainer/PanelContainer/VBoxContainer/Strength/Add

@onready var agility_label = $CenterContainer/PanelContainer/VBoxContainer/Agility/AgilityPoints
@onready var agility_button = $CenterContainer/PanelContainer/VBoxContainer/Agility/Add

@onready var intelligence_label = $CenterContainer/PanelContainer/VBoxContainer/Intelligence/IntelligencePoints
@onready var intelligence_button = $CenterContainer/PanelContainer/VBoxContainer/Intelligence/Add

@onready var vitality_label = $CenterContainer/PanelContainer/VBoxContainer/Vitality/VitalityPoints
@onready var vitality_button = $CenterContainer/PanelContainer/VBoxContainer/Vitality/Add


func _ready():

	hide()

	var selected_hero = _find_selected_hero()

	if is_instance_valid(selected_hero):

		character_stats = selected_hero.get_node_or_null("CharacterStats")
		if not is_instance_valid(character_stats):
			character_stats = selected_hero.find_child("CharacterStats", true, false)

		character_stats.level_up_occurred.connect(_on_level_up)


	close_button.pressed.connect(_on_close_pressed)

	strength_button.pressed.connect(_on_strength_pressed)
	agility_button.pressed.connect(_on_agility_pressed)
	intelligence_button.pressed.connect(_on_intelligence_pressed)
	vitality_button.pressed.connect(_on_vitality_pressed)


func _on_level_up():

	update_stats()


func update_stats():

	if not character_stats:
		return

	points_label.text = "(" + str(character_stats.attribute_points) + ")"

	strength_label.text = "(" + str(character_stats.get_total_strength()) + ")"

	agility_label.text = "(" + str(character_stats.get_total_agility()) + ")"

	intelligence_label.text = "(" + str(character_stats.get_total_intelligence()) + ")"

	vitality_label.text = "(" + str(character_stats.get_total_vitality()) + ")"


func _on_close_pressed():

	hide()


func _on_strength_pressed():

	character_stats.add_attribute_point("strength")

	SaveManager.save_character(character_stats)

	update_stats()


func _on_agility_pressed():

	character_stats.add_attribute_point("agility")

	SaveManager.save_character(character_stats)

	update_stats()


func _on_intelligence_pressed():

	character_stats.add_attribute_point("intelligence")

	SaveManager.save_character(character_stats)

	update_stats()


func _on_vitality_pressed():

	character_stats.add_attribute_point("vitality")

	SaveManager.save_character(character_stats)

	update_stats()


func _find_selected_hero() -> Node:
	var manager := get_tree().get_first_node_in_group("party_manager") as PartyManager
	if is_instance_valid(manager):
		var main_hero := manager.get_main_hero()
		if is_instance_valid(main_hero):
			return main_hero
	var selected_id := CharacterSelectionData.get_selected_character_id()
	for candidate in get_tree().get_nodes_in_group("party_heroes"):
		if not is_instance_valid(candidate):
			continue
		var stats = candidate.get("character_stats")
		if not is_instance_valid(stats):
			stats = candidate.get_node_or_null("CharacterStats")
		if is_instance_valid(stats) and CharacterSelectionData.normalize_hero_id(str(stats.get("hero_id"))) == selected_id:
			return candidate
	return null
