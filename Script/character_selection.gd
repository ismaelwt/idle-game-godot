
extends Node3D

@onready var mage: Node3D = $SubViewportContainer/SubViewport/Mage
@onready var knight: Node3D = $SubViewportContainer/SubViewport/Knight
@onready var spotlight: SpotLight3D = $SubViewportContainer/SubViewport/World/SelectionSpotlight

@onready var spotlight_position1: Node3D = $SubViewportContainer/SubViewport/World/SpotLightPosition1
@onready var spotlight_position2: Node3D = $SubViewportContainer/SubViewport/World/SpotLightPosition2

@onready var next: TextureButton = $SubViewportContainer/CanvasLayer/Panel/Next
@onready var previous: TextureButton = $SubViewportContainer/CanvasLayer/Panel/Previous

@onready var start_button: TextureButton = $SubViewportContainer/CanvasLayer/Panel/StartButton
var characters: Array[Node3D] = []
var selected_index: int = 0


func _ready() -> void:
	characters = [knight, mage]
	next.pressed.connect(select_next)
	previous.pressed.connect(select_previous)
	start_button.pressed.connect(on_started_pressed)
	update_selection()

func select_next() -> void:
	selected_index = (selected_index + 1) % characters.size()
	update_selection()


func select_previous() -> void:
	selected_index = (selected_index - 1 + characters.size()) % characters.size()
	update_selection()

func on_started_pressed() -> void:
	var selected_character: Node3D = characters[selected_index]

	if selected_character == mage:
		CharacterSelectionData.selected_character = "mage"
	else:
		CharacterSelectionData.selected_character = "knight"

	print(
		"Classe escolhida: ",
		CharacterSelectionData.selected_character
	)

	SceneLoader.change_scene("res://Scenes/level_1.tscn")


func update_selection() -> void:
	var selected_character: Node3D = characters[selected_index]

	if selected_character == mage:
		spotlight.global_position = spotlight_position2.global_position
	else:
		spotlight.global_position = spotlight_position1.global_position

	print("Personagem selecionado: ", selected_character.name)
