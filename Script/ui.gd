
extends Control

const CHARACTER_HUD_SCENE: PackedScene = preload("res://Scenes/character_hud.tscn")
const RETRY_PANEL_SCENE: PackedScene = preload("res://Scenes/retry_panel.tscn")

func _enter_tree() -> void:
	# RetryPanel precisa existir antes da HUD, pois a HUD resolve ../RetryPanel em @onready.
	if get_node_or_null("RetryPanel") == null:
		var retry_panel := RETRY_PANEL_SCENE.instantiate()
		retry_panel.name = "RetryPanel"
		add_child(retry_panel)

	if get_node_or_null("CharacterHUD") == null:
		var character_hud := CHARACTER_HUD_SCENE.instantiate()
		character_hud.name = "CharacterHUD"
		# A raiz da HUD ocupa a tela inteira; não deve bloquear cliques no RetryPanel.
		character_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(character_hud)

const CharacterSelectionDataScript = preload("res://Script/character_selection_data.gd")
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

const SKILL_ICONS: Dictionary = {
	"fireball": preload("res://icons/fire-ray-2.png"),
	"energy_ball": preload("res://icons/energyball-icon-2.png"),
	"damage_buff": preload("res://icons/frenesi.png"),
	"frenesi": preload("res://icons/frenesi.png"),
	"heal": preload("res://icons/heart-plus-2.png"),
	"thunderstorm": preload("res://icons/thuderstorm-icon.png"),
	"earthquake": preload("res://icons/earthquake.png"),
}

# Os ícones podem ser definidos diretamente nas cenas das habilidades.
# Caso a propriedade icon não exista ou seja nula, o slot fica vazio.

var mage_hero: Node3D = null
var knight_hero: Node3D = null
var selected_hero_id: String = ""

var mage_skill_icons: Array[TextureRect] = []
var knight_skill_icons: Array[TextureRect] = []

var mage_cooldown_labels: Array[Label] = []
var knight_cooldown_labels: Array[Label] = []
var connected_skill_stats: Array[Node] = []

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
	# Party e ícones são atualizados por sinais; aqui ficam apenas os cooldowns.

	# Evita passar referências liberadas para parâmetros tipados.
	var active_mage: Node3D = mage_hero if is_instance_valid(mage_hero) else null
	var active_knight: Node3D = knight_hero if is_instance_valid(knight_hero) else null
	_update_cooldowns(active_mage, mage_cooldown_labels)
	_update_cooldowns(active_knight, knight_cooldown_labels)


# =========================================================
# LOCALIZAÇÃO DOS HERÓIS
# =========================================================

func before_level_unload() -> void:
	# Guarda o herói selecionado antes de destruir a fase atual.
	if selected_hero_id.is_empty():
		for child in get_children():
			if not child.has_method("set_selected_hero"):
				continue
			var stats = child.get("character_stats")
			if is_instance_valid(stats):
				selected_hero_id = str(stats.get("hero_id"))
				break

		if selected_hero_id.is_empty():
			var hud := get_node_or_null("CharacterHUD")
			if is_instance_valid(hud):
				var selected = hud.get("selected_hero")
				if is_instance_valid(selected):
					var stats = selected.get("character_stats")
					if is_instance_valid(stats):
						selected_hero_id = str(stats.get("hero_id"))

	# Desconecta e limpa referências da fase que será removida.
	if is_instance_valid(party_manager):
		if party_manager.party_changed.is_connected(_on_party_changed):
			party_manager.party_changed.disconnect(_on_party_changed)

	party_manager = null
	combat_controller = null
	mage_hero = null
	knight_hero = null


func on_level_loaded() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	party_manager = scene.find_child("PartyManager", true, false) as PartyManager
	combat_controller = scene.find_child("CombatController", true, false) as CombatController
	if is_instance_valid(party_manager) and not party_manager.party_changed.is_connected(_on_party_changed):
		party_manager.party_changed.connect(_on_party_changed)
	_refresh_heroes()

	var hud := get_node_or_null("CharacterHUD")
	if is_instance_valid(hud) and hud.has_method("on_level_loaded"):
		hud.call("on_level_loaded", party_manager)

	var selected_hero: Node = null
	if is_instance_valid(party_manager):
		if not selected_hero_id.is_empty():
			for hero in party_manager.get_heroes():
				if not is_instance_valid(hero):
					continue
				var stats = hero.get("character_stats")
				if is_instance_valid(stats) and str(stats.get("hero_id")) == selected_hero_id:
					selected_hero = hero
					break
		if not is_instance_valid(selected_hero):
			selected_hero = party_manager.get_main_hero()
		if not is_instance_valid(selected_hero):
			var heroes: Array[Node3D] = party_manager.get_heroes()
			if not heroes.is_empty():
				selected_hero = heroes[0]

	if is_instance_valid(selected_hero):
		selected_hero_id = str(selected_hero.get("character_stats").get("hero_id"))

	for child in get_children():
		if child.has_method("set_selected_hero") and is_instance_valid(selected_hero):
			child.call("set_selected_hero", selected_hero)


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

		var hero_id := CharacterSelectionDataScript.normalize_hero_id(str(stats.get("hero_id")))

		if hero_id == "mage":
			new_mage = hero
		elif hero_id == "knight":
			new_knight = hero

	mage_hero = new_mage
	knight_hero = new_knight

	_connect_skill_order_signals()

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

	var hero_id := CharacterSelectionDataScript.normalize_hero_id(str(stats.get("hero_id")))
	return hero_id == "knight"


func _is_mage(hero: Node) -> bool:
	if not is_instance_valid(hero):
		return false

	var stats = hero.get("character_stats")
	if not is_instance_valid(stats):
		return false

	var hero_id := CharacterSelectionDataScript.normalize_hero_id(str(stats.get("hero_id")))
	return hero_id == "mage"


func _on_party_changed(_heroes: Array[Node3D]) -> void:
	_refresh_heroes()


func _connect_skill_order_signals() -> void:
	# Remove conexões dos heróis anteriores para não manter referências obsoletas.
	for stats in connected_skill_stats:
		if is_instance_valid(stats) and stats.skill_order_changed.is_connected(_on_skill_order_changed):
			stats.skill_order_changed.disconnect(_on_skill_order_changed)

	connected_skill_stats.clear()

	for hero in [mage_hero, knight_hero]:
		if not is_instance_valid(hero):
			continue

		var stats = hero.get("character_stats")
		if not is_instance_valid(stats) or not stats.has_signal("skill_order_changed"):
			continue

		if not stats.skill_order_changed.is_connected(_on_skill_order_changed):
			stats.skill_order_changed.connect(_on_skill_order_changed)
		connected_skill_stats.append(stats)


func _on_skill_order_changed() -> void:
	if is_instance_valid(mage_hero):
		_update_skill_icons(mage_hero, mage_skill_icons)
	if is_instance_valid(knight_hero):
		_update_skill_icons(knight_hero, knight_skill_icons)


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

		var texture: Texture2D = SKILL_ICONS.get(skill_id) as Texture2D
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
