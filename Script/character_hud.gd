
extends Control

const MAP_SCENE: PackedScene = preload("res://Scenes/minimap.tscn")
const SHOP_SCENE: PackedScene = preload("res://Scenes/companion_shop.tscn")

var font = preload("res://Fonts/Pix32.ttf")
var map_panel: Control
var shop_panel: Control

# HERÓI SELECIONADO
var player: Node3D = null

# VIDA E MANA
@onready var mage_health_bar: ProgressBar = $VBoxContainer/MageUI/HealthFrame/HealthProgressBar
@onready var mage_mana_bar: ProgressBar = $VBoxContainer/MageUI/ManaFrame/ManaProgressBar

# XP E NÍVEL
@onready var mage_level_label: Label = $VBoxContainer/MageUI/LevelContainer/LevelLabel
@onready var mage_xp_bar: ProgressBar = $VBoxContainer/MageUI/XpBarControl/XPBar

@onready var knight_health_bar: ProgressBar = $VBoxContainer/KnightUI/HealthFrame/HealthProgressBar
@onready var knight_mana_bar: ProgressBar = $VBoxContainer/KnightUI/ManaFrame/ManaProgressBar

@onready var knight_level_label: Label = $VBoxContainer/KnightUI/LevelContainer/LevelLabel
@onready var knight_xp_bar: ProgressBar = $VBoxContainer/KnightUI/XpBarControl/XPBar

# BOTÕES
@onready var map_button: TextureButton = $HBoxContainer/MapButton
@onready var skill_tree_button: TextureButton = $HBoxContainer/SkillTreeButton
@onready var skill_tree_button_points_label: Label = $HBoxContainer/SkillTreeButton/PointsLabel

@onready var status_player: Control = $"../Status"
@onready var status_button: TextureButton = $HBoxContainer/StatusButton

@onready var retry_panel: Control = $"../RetryPanel"
@onready var retry_panel_button: TextureButton = $HBoxContainer/RetryPanelButton

@onready var skill_tree: Control = $"../SkillTree"
@onready var shop_button: TextureButton = $CompanionShop

func _ready() -> void:
	shop_button.pressed.connect(_on_shop_button_pressed)
	map_button.pressed.connect(_on_map_button_pressed)
	skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	status_button.pressed.connect(_on_status_button_pressed)
	retry_panel_button.pressed.connect(_on_retry_panel_button_pressed)

	_update_selected_hero()


func _process(_delta: float) -> void:
	# Detecta se o herói selecionado mudou.
	_update_selected_hero()

	if not is_instance_valid(player):
		return

	var character_stats = player.get("character_stats")

	if not is_instance_valid(character_stats):
		return

	# PONTOS DE HABILIDADE
	skill_tree_button_points_label.text = str(character_stats.skill_points)

	# NÍVEL
	mage_level_label.text = "Lv. " + str(character_stats.level)
	knight_level_label.text = "Lv. " + str(character_stats.level)

	# VIDA
	mage_health_bar.max_value = maxf(float(player.max_health), 1.0)
	mage_health_bar.value = clampf(
		float(player.health),
		0.0,
		float(player.max_health)
	)
	
	knight_health_bar.max_value = maxf(float(player.max_health), 1.0)
	knight_health_bar.value = clampf(
		float(player.health),
		0.0,
		float(player.max_health)
	)

	# MANA
	mage_mana_bar.max_value = maxf(float(character_stats.max_mana), 1.0)
	mage_mana_bar.value = clampf(
		float(character_stats.mana),
		0.0,
		float(character_stats.max_mana)
	)
	
	knight_mana_bar.max_value = maxf(float(character_stats.max_mana), 1.0)
	knight_mana_bar.value = clampf(
		float(character_stats.mana),
		0.0,
		float(character_stats.max_mana)
	)

	# XP
	mage_xp_bar.max_value = maxf(float(character_stats.xp_to_next_level), 1.0)
	mage_xp_bar.value = clampf(
		float(character_stats.xp),
		0.0,
		float(character_stats.xp_to_next_level)
	)
	
	knight_xp_bar.max_value = maxf(float(character_stats.xp_to_next_level), 1.0)
	knight_xp_bar.value = clampf(
		float(character_stats.xp),
		0.0,
		float(character_stats.xp_to_next_level)
	)


func _update_selected_hero() -> void:
	var selected_id := str(CharacterSelectionData.selected_character).to_lower()
	var hero_name := "Knight" if selected_id == "knight" else "Player"

	var selected_hero := get_tree().current_scene.find_child(
		hero_name,
		true,
		false
	) as Node3D

	if is_instance_valid(selected_hero):
		player = selected_hero


func _on_skill_tree_button_pressed() -> void:
	skill_tree.visible = not skill_tree.visible


func _on_status_button_pressed() -> void:
	_update_selected_hero()

	if not is_instance_valid(player):
		push_warning("Não foi possível encontrar o herói selecionado.")
		return

	if not is_instance_valid(status_player):
		push_warning("Painel de status não encontrado.")
		return

	status_player.set_selected_hero(player)
	status_player.visible = not status_player.visible


func _on_retry_panel_button_pressed() -> void:
	retry_panel.visible = not retry_panel.visible


func _on_map_button_pressed() -> void:
	if map_panel == null:
		map_panel = MAP_SCENE.instantiate()
		get_parent().add_child(map_panel)
		return

	map_panel.visible = not map_panel.visible

func _on_shop_button_pressed() -> void:
	if shop_panel == null:
		shop_panel = SHOP_SCENE.instantiate()
		get_parent().add_child(shop_panel)
		shop_panel.show();
		return

	shop_panel.visible = not shop_panel.visible
