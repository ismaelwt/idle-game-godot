
extends CanvasLayer

# =========================================================
# REFERÊNCIAS
# =========================================================

@onready var mage_ui: Control = $CharacterHUD/VBoxContainer/MageUI
@onready var knight_ui: Control = $CharacterHUD/VBoxContainer/KnightUI

@onready var party_manager: PartyManager = (
	get_tree().current_scene.find_child("PartyManager", true, false)
	as PartyManager
)

@onready var combat_controller: CombatController = (
	get_tree().current_scene.find_child("CombatController", true, false)
	as CombatController
)

# =========================================================
# HABILIDADES
# =========================================================

const SKILL_SCENES: Dictionary = {
	"fireball": "res://Scenes/fireball_v1.tscn",
	"energy_ball": "res://Scenes/energy_ball.tscn",
	"damage_buff": "res://Scenes/damage_buff.tscn",
	"heal": "res://Scenes/healing_effect.tscn",
	"thunderstorm": "res://Scenes/thunderstorm.tscn",
	"frenesi": "res://Scenes/damage_buff.tscn",
}

# Os ícones podem ser definidos diretamente nas cenas das habilidades.
# Caso a propriedade icon não exista ou seja nula, o slot fica vazio.

var mage_hero: Node3D = null
var knight_hero: Node3D = null

var mage_skill_icons: Array[TextureRect] = []
var knight_skill_icons: Array[TextureRect] = []

var mage_cooldown_labels: Array[Label] = []
var knight_cooldown_labels: Array[Label] = []

# =========================================================
# INICIALIZAÇÃO
# =========================================================

func _ready() -> void:
	_cache_skill_slots()

	if is_instance_valid(party_manager):
		if not party_manager.party_changed.is_connected(_on_party_changed):
			party_manager.party_changed.connect(_on_party_changed)

	_refresh_heroes()

	# Segunda verificação depois da inicialização dos personagens.
	await get_tree().process_frame
	_refresh_heroes()


func _process(_delta: float) -> void:
	# Detecta personagens adicionados/removidos durante a partida.
	_refresh_heroes()

	_update_cooldowns(mage_hero, mage_cooldown_labels)
	_update_cooldowns(knight_hero, knight_cooldown_labels)


# =========================================================
# LOCALIZAÇÃO DOS HERÓIS
# =========================================================

func _refresh_heroes() -> void:
	var active_party_manager := party_manager

	if not is_instance_valid(active_party_manager):
		var scene := get_tree().current_scene
		if scene == null:
			return

		active_party_manager = scene.find_child(
			"PartyManager", true, false
		) as PartyManager

		if not is_instance_valid(active_party_manager):
			return

		party_manager = active_party_manager

	var active_heroes: Array[Node3D] = (
		active_party_manager.get_heroes()
	)

	var new_mage: Node3D = null
	var new_knight: Node3D = null

	for hero in active_heroes:
		if not is_instance_valid(hero):
			continue

		if not _has_valid_stats(hero):
			continue

		var stats: Node = hero.get_node_or_null("CharacterStats")
		if stats == null:
			stats = hero.find_child(
				"CharacterStats", true, false
			)

		if stats == null:
			continue

		var hero_id := CharacterSelectionData.normalize_hero_id(str(stats.get("hero_id")))

		if hero_id == "mage":
			new_mage = hero
		elif hero_id == "knight":
			new_knight = hero

	mage_hero = new_mage
	knight_hero = new_knight

	mage_ui.visible = is_instance_valid(mage_hero)
	knight_ui.visible = is_instance_valid(knight_hero)

	if is_instance_valid(mage_hero):
		_update_skill_icons(mage_hero, mage_skill_icons)

	if is_instance_valid(knight_hero):
		_update_skill_icons(knight_hero, knight_skill_icons)


func _has_valid_stats(hero: Node) -> bool:
	if not is_instance_valid(hero):
		return false

	var stats: Node = hero.get_node_or_null("CharacterStats")

	if stats == null:
		stats = hero.find_child(
			"CharacterStats", true, false
		)

	return is_instance_valid(stats)

func _is_hero_alive(hero: Node3D) -> bool:
	if not is_instance_valid(hero):
		return false

	if not hero.is_inside_tree():
		return false

	var dead_value = hero.get("dead")
	if dead_value != null and bool(dead_value):
		return false

	return true


func _is_knight(hero: Node) -> bool:
	if not is_instance_valid(hero):
		return false

	var stats = hero.get("character_stats")
	if not is_instance_valid(stats):
		return false

	var hero_id := CharacterSelectionData.normalize_hero_id(str(stats.get("hero_id")))
	return hero_id == "knight"


func _is_mage(hero: Node) -> bool:
	if not is_instance_valid(hero):
		return false

	var stats = hero.get("character_stats")
	if not is_instance_valid(stats):
		return false

	var hero_id := CharacterSelectionData.normalize_hero_id(str(stats.get("hero_id")))
	return hero_id == "mage"


func _on_party_changed(_heroes: Array[Node3D]) -> void:
	_refresh_heroes()


# =========================================================
# SLOTS DA BARRA
# =========================================================

func _cache_skill_slots() -> void:
	_cache_slots_for_ui(
		mage_ui,
		mage_skill_icons,
		mage_cooldown_labels
	)

	_cache_slots_for_ui(
		knight_ui,
		knight_skill_icons,
		knight_cooldown_labels
	)


func _cache_slots_for_ui(
	panel: Control,
	icons: Array[TextureRect],
	cooldown_labels: Array[Label]
) -> void:
	var container := panel.get_node_or_null(
		"SkillBar/SkillContainer"
	)

	if container == null:
		push_warning(
			"UI: SkillContainer não encontrado em " + panel.name
		)
		return

	for slot_name in ["Skill1", "Skill2", "Skill3"]:
		var slot := container.get_node_or_null(slot_name)

		if slot == null:
			push_warning(
				"UI: " + slot_name + " não encontrado em " + panel.name
			)
			continue

		var icon := slot.get_node_or_null("Icon") as TextureRect
		var cooldown := slot.get_node_or_null("CooldownLabel") as Label

		icons.append(icon)
		cooldown_labels.append(cooldown)


# =========================================================
# ÍCONES INDIVIDUAIS
# =========================================================

func _update_skill_icons(
	hero: Node3D,
	icons: Array[TextureRect]
) -> void:
	if not is_instance_valid(hero):
		return

	var stats = hero.get("character_stats")
	if not is_instance_valid(stats):
		return

	var order: Array = stats.get("skill_order")

	for i in range(icons.size()):
		var icon := icons[i]

		if not is_instance_valid(icon):
			continue

		icon.texture = null
		icon.visible = false

		if i >= order.size():
			continue

		var skill_id := str(order[i])

		if not stats.has_skill(skill_id):
			continue

		if not SKILL_SCENES.has(skill_id):
			continue

		var scene_path: String = SKILL_SCENES[skill_id]
		var skill_scene := load(scene_path) as PackedScene

		if skill_scene == null:
			push_warning(
				"UI: cena não encontrada para a skill " + skill_id
			)
			continue

		var skill_instance := skill_scene.instantiate()
		var texture: Texture2D = null

		for property_info in skill_instance.get_property_list():
			if str(property_info.get("name")) == "icon":
				var value = skill_instance.get("icon")
				if value is Texture2D:
					texture = value
				break

		skill_instance.free()

		icon.texture = texture
		icon.visible = texture != null


# =========================================================
# COOLDOWNS
# =========================================================

func _update_cooldowns(
	hero: Node3D,
	labels: Array[Label]
) -> void:
	if not is_instance_valid(hero):
		for label in labels:
			if is_instance_valid(label):
				label.text = ""
		return

	var stats = hero.get("character_stats")
	if not is_instance_valid(stats):
		return

	var skill_order: Array = stats.get("skill_order")

	var state_dictionary = combat_controller.get("hero_skill_states") \
		if is_instance_valid(combat_controller) else {}

	var hero_state: Dictionary = {}

	if state_dictionary is Dictionary:
		hero_state = state_dictionary.get(hero.get_instance_id(), {})

	var skill_ids: Array = hero_state.get("skill_ids", [])
	var timers: Array = hero_state.get("skill_timers", [])
	var available: Array = hero_state.get("skill_available", [])

	for i in range(labels.size()):
		var label := labels[i]

		if not is_instance_valid(label):
			continue

		if i >= skill_order.size():
			label.text = ""
			continue

		var skill_id := str(skill_order[i])

		# Sem estado de combate ainda: skill configurada começa pronta.
		if hero_state.is_empty():
			label.text = "✓" if stats.has_skill(skill_id) else ""
			continue

		var timer_index := skill_ids.find(skill_id)

		if timer_index < 0:
			label.text = ""
			continue

		if timer_index >= timers.size() or timer_index >= available.size():
			label.text = ""
			continue

		var remaining := float(timers[timer_index])
		var is_available := bool(available[timer_index])

		if not is_available and remaining > 0.0:
			label.text = str(snapped(remaining, 0.1))
		else:
			label.text = "✓"
