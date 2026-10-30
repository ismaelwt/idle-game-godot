
extends Control

const MAP_SCENE: PackedScene = preload("res://Scenes/minimap.tscn")
const SHOP_SCENE: PackedScene = preload("res://Scenes/companion_shop.tscn")

var font = preload("res://Fonts/Pix32.ttf")
var map_panel: Control
var shop_panel: Control

# HERÓIS DA EQUIPE
var selected_hero: Node3D = null
var mage_hero: Node3D = null
var knight_hero: Node3D = null
var party_manager: PartyManager = null

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

	var scene := get_tree().current_scene
	if scene != null:
		party_manager = scene.find_child(
			"PartyManager", true, false
		) as PartyManager

	if not is_instance_valid(party_manager):
		party_manager = get_node_or_null("/root/PartyManager") as PartyManager

	if is_instance_valid(party_manager):
		if not party_manager.party_changed.is_connected(_on_party_changed):
			party_manager.party_changed.connect(_on_party_changed)

	_refresh_heroes()
	call_deferred("_refresh_heroes")


func _process(_delta: float) -> void:
	# Um herói pode ter sido liberado ao morrer/removido da cena.
	# Atualiza a equipe antes de passar referências antigas para funções tipadas.
	var mage_was_assigned := mage_hero != null
	var knight_was_assigned := knight_hero != null
	var selected_hero_was_assigned := selected_hero != null

	if (
		(mage_was_assigned and not is_instance_valid(mage_hero))
		or (knight_was_assigned and not is_instance_valid(knight_hero))
		or (selected_hero_was_assigned and not is_instance_valid(selected_hero))
	):
		_refresh_heroes()

	# Só chamar a função com referências ainda válidas.
	if is_instance_valid(mage_hero):
		_update_hero_ui(mage_hero, "mage")
	else:
		$VBoxContainer/MageUI.visible = false

	if is_instance_valid(knight_hero):
		_update_hero_ui(knight_hero, "knight")
	else:
		$VBoxContainer/KnightUI.visible = false

	# Os pontos de habilidade e o painel de status pertencem ao herói principal.
	_update_selected_hero()

	if is_instance_valid(selected_hero):
		var stats := _get_character_stats(selected_hero)
		if is_instance_valid(stats):
			skill_tree_button_points_label.text = str(stats.get("skill_points"))


func _refresh_heroes() -> void:
	var manager := party_manager

	if not is_instance_valid(manager):
		var scene := get_tree().current_scene
		if scene == null:
			return
		manager = scene.find_child("PartyManager", true, false) as PartyManager
		if not is_instance_valid(manager):
			manager = get_node_or_null("/root/PartyManager") as PartyManager
		if not is_instance_valid(manager):
			return
		party_manager = manager

	var new_mage: Node3D = null
	var new_knight: Node3D = null

	for hero in manager.get_heroes():
		if not is_instance_valid(hero):
			continue

		var stats := _get_character_stats(hero)
		if not is_instance_valid(stats):
			continue

		var hero_id := CharacterSelectionData.normalize_hero_id(str(stats.get("hero_id")))

		match hero_id:
			"mage":
				new_mage = hero
			"knight":
				new_knight = hero

	mage_hero = new_mage
	knight_hero = new_knight

	$VBoxContainer/MageUI.visible = is_instance_valid(mage_hero)
	$VBoxContainer/KnightUI.visible = is_instance_valid(knight_hero)

	# Mantém selected_hero como referência ao herói principal para os botões existentes.
	_update_selected_hero()


func _get_character_stats(hero: Node) -> Node:
	if not is_instance_valid(hero):
		return null

	# Compatibilidade com scripts que guardam CharacterStats em uma propriedade.
	var stats: Node = hero.get("character_stats")
	if is_instance_valid(stats):
		return stats

	stats = hero.get_node_or_null("CharacterStats")
	if stats == null:
		stats = hero.find_child("CharacterStats", true, false)

	return stats


func _update_hero_ui(hero: Node3D, hero_id: String) -> void:
	if not is_instance_valid(hero):
		return

	var stats := _get_character_stats(hero)
	if not is_instance_valid(stats):
		return

	var health_bar: ProgressBar
	var mana_bar: ProgressBar
	var level_label: Label
	var xp_bar: ProgressBar

	match hero_id:
		"mage":
			health_bar = mage_health_bar
			mana_bar = mage_mana_bar
			level_label = mage_level_label
			xp_bar = mage_xp_bar
		"knight":
			health_bar = knight_health_bar
			mana_bar = knight_mana_bar
			level_label = knight_level_label
			xp_bar = knight_xp_bar
		_:
			return

	var max_health := maxf(float(hero.get("max_health")), 1.0)
	var health := float(hero.get("health"))
	health_bar.max_value = max_health
	health_bar.value = clampf(health, 0.0, max_health)

	var max_mana := maxf(float(stats.get("max_mana")), 1.0)
	var mana := float(stats.get("mana"))
	mana_bar.max_value = max_mana
	mana_bar.value = clampf(mana, 0.0, max_mana)

	level_label.text = "Lv. " + str(stats.get("level"))

	var xp_required := maxf(float(stats.get("xp_to_next_level")), 1.0)
	var xp := float(stats.get("xp"))
	xp_bar.max_value = xp_required
	xp_bar.value = clampf(xp, 0.0, xp_required)


func _on_party_changed(_heroes: Array[Node3D]) -> void:
	_refresh_heroes()


func _update_selected_hero() -> void:
	# A seleção usada pelo Status é de gerenciamento, não de combate.
	# Mantém o herói principal selecionado mesmo se estiver morto, desde que
	# sua instância ainda exista; morte não deve impedir acesso a atributos/equipamentos.
	if is_instance_valid(party_manager):
		var main_hero := party_manager.get_main_hero()
		if is_instance_valid(main_hero):
			selected_hero = main_hero
			return

	var selected_id := CharacterSelectionData.get_selected_character_id()
	if selected_id == "knight":
		selected_hero = knight_hero
	else:
		selected_hero = mage_hero

func _on_skill_tree_button_pressed() -> void:
	_update_selected_hero()

	if not is_instance_valid(selected_hero):
		push_warning("Não foi possível encontrar o herói principal para abrir a Skill Tree.")
		return

	if is_instance_valid(skill_tree) and skill_tree.has_method("set_selected_hero"):
		skill_tree.set_selected_hero(selected_hero)

	skill_tree.visible = not skill_tree.visible


func _on_status_button_pressed() -> void:
	_update_selected_hero()

	# O herói pode estar morto e ainda assim precisa continuar gerenciável.
	if not is_instance_valid(selected_hero):
		push_warning("Não foi possível encontrar o herói selecionado.")
		return

	if not is_instance_valid(status_player):
		push_warning("Painel de status não encontrado.")
		return

	status_player.set_selected_hero(selected_hero)
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
