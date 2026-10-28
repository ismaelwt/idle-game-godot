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

	var player = get_tree().get_first_node_in_group("player")

	if player:

		character_stats = player.get_node("CharacterStats")

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
