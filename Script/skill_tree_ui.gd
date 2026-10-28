
extends Panel

# ID da skill exibida em cada botão.
# Para reorganizar a árvore, basta alterar estes valores.

const MAGE_SKILL_BUTTONS := {
	"skill1_nv1": "fireball",
	"skill2_nv1": "damage_buff",
	"skill3_nv1": "energy_ball",
	"skill1_nv2": "heal",
	"skill2_nv2": "thunderstorm"
}

# IDs reservados para a árvore do Knight.
# As habilidades precisam existir no SkillTree global para aparecerem.
const KNIGHT_SKILL_BUTTONS := {
	"skill1_nv1": "frenesi"
}

@export_enum("Mage", "Knight") var tree_class: String = "Mage"

# =========================================================
# INTERFACE
# =========================================================

@onready var points_label = $CenterContainer/Control/PanelContainer/Points
@onready var available_points_label = $CenterContainer/Control/PanelContainer/Points/AvailablePoints

# Painéis que bloqueiam cada estágio
@onready var panel_stage1 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/Panel
@onready var panel_stage2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/Panel2

# Skills do estágio 1
@onready var skill1_nv1 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv1Container/HBoxContainer/MarginContainerSkill1/VBoxContainerSkill1/Panel/Skill1
@onready var skill2_nv1 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv1Container/HBoxContainer/MarginContainerSkill2/VBoxContainerSkill2/Panel/Skill2
@onready var skill3_nv1 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv1Container/HBoxContainer/MarginContainerSkill3/VBoxContainerSkill3/Panel/Skill3

# Skills do estágio 2
@onready var skill1_nv2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv2Container/HBoxContainer/MarginContainerSkill1/VBoxContainerSkill1/Panel/Skill1
@onready var skill2_nv2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv2Container/HBoxContainer/MarginContainerSkill2/VBoxContainerSkill2/Panel/Skill2
@onready var skill3_nv2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv2Container/HBoxContainer/MarginContainerSkill3/VBoxContainerSkill3/Panel/Skill3

# Barra de progressão
@onready var progress_button = $CenterContainer/Control/PanelContainer/AddSkilOnProgressBarButton
@onready var progress_bar = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlProgressBar/ProgressBar

@onready var close_button = $CenterContainer/Control/PanelContainer/CloseButton


@onready var add_skill1 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv1Container/HBoxContainer/MarginContainerSkill1/VBoxContainerSkill1/Panel/AddSkill
@onready var remove_skill1 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv1Container/HBoxContainer/MarginContainerSkill1/VBoxContainerSkill1/Panel/RemoveSkill

@onready var add_skill2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv1Container/HBoxContainer/MarginContainerSkill2/VBoxContainerSkill2/Panel/AddSkill
@onready var remove_skill2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv1Container/HBoxContainer/MarginContainerSkill2/VBoxContainerSkill2/Panel/RemoveSkill

@onready var add_skill3 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv1Container/HBoxContainer/MarginContainerSkill3/VBoxContainerSkill3/Panel/AddSkill
@onready var remove_skill3 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv1Container/HBoxContainer/MarginContainerSkill3/VBoxContainerSkill3/Panel/RemoveSkill

@onready var add_skill1_nv2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv2Container/HBoxContainer/MarginContainerSkill1/VBoxContainerSkill1/Panel/AddSkill
@onready var remove_skill1_nv2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv2Container/HBoxContainer/MarginContainerSkill1/VBoxContainerSkill1/Panel/RemoveSkill

@onready var add_skill2_nv2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv2Container/HBoxContainer/MarginContainerSkill2/VBoxContainerSkill2/Panel/AddSkill
@onready var remove_skill2_nv2 = $CenterContainer/Control/PanelContainer/ScrollContainer/Control/ControlContainer/VBoxContainerSkillNv2Container/HBoxContainer/MarginContainerSkill2/VBoxContainerSkill2/Panel/RemoveSkill

@onready var skill_change_dialog: ConfirmationDialog = $SkillChangeDialog

var pending_skill_id: String = ""
var pending_action: String = ""

# =========================================================
# DADOS
# =========================================================

var character_stats

var _skill_buttons_by_key: Dictionary = {}
var _add_buttons_by_key: Dictionary = {}
var _remove_buttons_by_key: Dictionary = {}


func _get_skill_mapping() -> Dictionary:
	if tree_class.to_lower() == "knight":
		return KNIGHT_SKILL_BUTTONS
	return MAGE_SKILL_BUTTONS


func _get_skill_button_nodes() -> Dictionary:
	return {
		"skill1_nv1": skill1_nv1,
		"skill2_nv1": skill2_nv1,
		"skill3_nv1": skill3_nv1,
		"skill1_nv2": skill1_nv2,
		"skill2_nv2": skill2_nv2
	}


func _get_add_button_nodes() -> Dictionary:
	return {
		"skill1_nv1": add_skill1,
		"skill2_nv1": add_skill2,
		"skill3_nv1": add_skill3,
		"skill1_nv2": add_skill1_nv2,
		"skill2_nv2": add_skill2_nv2
	}


func _get_remove_button_nodes() -> Dictionary:
	return {
		"skill1_nv1": remove_skill1,
		"skill2_nv1": remove_skill2,
		"skill3_nv1": remove_skill3,
		"skill1_nv2": remove_skill1_nv2,
		"skill2_nv2": remove_skill2_nv2
	}


func _set_hero(hero: Node) -> void:
	if not is_instance_valid(hero):
		character_stats = null
		return

	var stats = hero.get("character_stats")
	
	print("HERÓI ENCONTRADO: ", hero.name)
	print("HERO ID: ", stats.get("hero_id"))
	print("HERO CLASS: ", stats.get("hero_class"))
	print("SELEÇÃO GLOBAL: ", CharacterSelectionData.selected_character)
	
	if stats == null:
		push_warning("SkillTreeUI: o herói selecionado não possui character_stats.")
		character_stats = null
		return

	character_stats = stats
	var hero_class_value = character_stats.get("hero_class")
	if hero_class_value != null:
		var normalized_class := str(hero_class_value).to_lower()
		if normalized_class == "knight" or normalized_class == "1":
			tree_class = "Knight"
		else:
			tree_class = "Mage"
			
	print("CLASSE FINAL DA ÁRVORE: ", tree_class)
	print("SKILLS DA ÁRVORE: ", _get_skill_mapping())
	update_tree()


# =========================================================
# INICIALIZAÇÃO
# =========================================================

func _ready() -> void:
	hide()

	skill_change_dialog.confirmed.connect(_on_skill_change_confirmed)
	progress_button.pressed.connect(_on_progress_button_pressed)
	close_button.pressed.connect(_on_close_pressed)

	_skill_buttons_by_key = _get_skill_button_nodes()
	_add_buttons_by_key = _get_add_button_nodes()
	_remove_buttons_by_key = _get_remove_button_nodes()

	for button_key in _skill_buttons_by_key:
		var skill_button: TextureButton = _skill_buttons_by_key[button_key]
		var add_button: TextureButton = _add_buttons_by_key[button_key]
		var remove_button: TextureButton = _remove_buttons_by_key[button_key]

		skill_button.pressed.connect(_on_skill_button_key_pressed.bind(button_key))
		add_button.pressed.connect(_on_add_skill_button_key_pressed.bind(button_key))
		remove_button.pressed.connect(_on_remove_skill_button_key_pressed.bind(button_key))

	# Resolve o herói atualmente selecionado pelo seletor de personagens.
	_refresh_selected_hero()


# Quando a janela é aberta, consulta novamente a seleção atual.
# Assim, a UI não fica presa ao primeiro herói encontrado em "player".
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		call_deferred("_refresh_selected_hero")


func _refresh_selected_hero() -> void:
	print("========== SKILL TREE DEBUG ==========")
	print("Seleção global: ", CharacterSelectionData.selected_character)
	var hero := _find_selected_hero()
	print("Herói encontrado: ", hero.name if is_instance_valid(hero) else "NENHUM")
	if is_instance_valid(hero):
		_set_hero(hero)
	else:
		character_stats = null
		push_warning("SkillTreeUI: não foi possível encontrar o herói selecionado.")


func _find_selected_hero() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null

	var selected := "mage"
	if is_instance_valid(CharacterSelectionData):
		selected = str(CharacterSelectionData.selected_character).to_lower()

	var candidate_names: Array[String] = []
	if selected == "knight":
		candidate_names = ["Knight", "knight"]
	else:
		candidate_names = ["Player", "Mage", "player", "mage"]

	for candidate_name in candidate_names:
		var candidate := scene.find_child(candidate_name, true, false)
		if candidate != null and candidate.get("character_stats") != null:
			return candidate

	# Fallback para projetos que registram os heróis no grupo comum.
	for candidate in get_tree().get_nodes_in_group("party_heroes"):
		if not is_instance_valid(candidate):
			continue
		var stats = candidate.get("character_stats")
		if stats != null and str(stats.get("hero_id")).to_lower() == selected:
			return candidate

	# Último fallback: mantém compatibilidade com a configuração antiga do Mage.
	if selected != "knight":
		var player := get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.get("character_stats") != null:
			return player

	return null


func _process(_delta: float) -> void:

	if not is_instance_valid(character_stats):
		return

	update_tree()


# =========================================================
# ATUALIZA A INTERFACE
# =========================================================


func update_tree() -> void:

	if not is_instance_valid(character_stats):
		return

	points_label.text = "POINTS: %d" % character_stats.skill_points
	available_points_label.text = "Unlocked Skill Lv: (%d)" % character_stats.unlocked_stage

	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.step = 1
	progress_bar.value = character_stats.stage_progress

	progress_button.disabled = (
		character_stats.skill_points <= 0
		or character_stats.unlocked_stage >= 2
	)

	panel_stage1.visible = character_stats.unlocked_stage < 1
	panel_stage2.visible = character_stats.unlocked_stage < 2

	var skill_buttons := {
		"skill1_nv1": [skill1_nv1, 1],
		"skill2_nv1": [skill2_nv1, 1],
		"skill3_nv1": [skill3_nv1, 1],
		"skill1_nv2": [skill1_nv2, 2],
		"skill2_nv2": [skill2_nv2, 2],
	}
	var skill_mapping := _get_skill_mapping()

	for button_key in skill_buttons:
		var button: TextureButton = skill_buttons[button_key][0]
		var required_stage: int = skill_buttons[button_key][1]

		var skill_id: String = str(skill_mapping.get(button_key, ""))
		if skill_id.is_empty():
			button.visible = false
			continue

		var skill_data: Dictionary = SkillTree.get_skill(skill_id)
		if skill_data.is_empty():
			button.visible = false
			continue

		button.visible = true

		var skill_name: String = skill_data.get("name", skill_id)

		update_skill_button(
			button,
			skill_id,
			skill_name,
			required_stage
		)
	
	for button_key in _add_buttons_by_key:
		var skill_id: String = str(skill_mapping.get(button_key, ""))
		var add_button: TextureButton = _add_buttons_by_key[button_key]
		var remove_button: TextureButton = _remove_buttons_by_key[button_key]

		if skill_id.is_empty() or not SkillTree.has_skill(skill_id):
			add_button.visible = false
			remove_button.visible = false
			continue

		update_skill_slot_buttons(skill_id, add_button, remove_button)


# =========================================================
# ESTADO VISUAL DAS SKILLS
# =========================================================



func update_skill_button(
	button: TextureButton,
	skill_id: String,
	_skill_name: String,
	required_stage: int
) -> void:

	button.tooltip_text = SkillTree.get_skill_description(skill_id)

	var icons: Dictionary = get_skill_icons(skill_id)

	var normal_icon: Texture2D = icons.get("normal") as Texture2D
	var disabled_icon: Texture2D = icons.get("disabled") as Texture2D

	var stage_unlocked: bool = (
		character_stats.unlocked_stage >= required_stage
	)

	var skill_learned: bool = (
		character_stats.has_skill(skill_id)
	)

	# Define a textura conforme o estado da habilidade.
	if skill_learned:
		if normal_icon != null:
			button.texture_normal = normal_icon

		if normal_icon != null:
			button.texture_disabled = normal_icon

		button.disabled = true
		return

	# Habilidade ainda não comprada: usa o ícone bloqueado.
	if disabled_icon != null:
		button.texture_normal = disabled_icon

	# Mantém o botão clicável para permitir a compra.
	button.disabled = false



# =========================================================
# COMPRAR SKILL CLICANDO DIRETAMENTE NELA
# =========================================================

func _on_skill_button_key_pressed(button_key: String) -> void:
	var skill_id: String = str(_get_skill_mapping().get(button_key, ""))
	if skill_id.is_empty():
		return
	_on_skill_pressed(skill_id)


func _on_add_skill_button_key_pressed(button_key: String) -> void:
	var skill_id: String = str(_get_skill_mapping().get(button_key, ""))
	if skill_id.is_empty():
		return
	_on_add_skill_pressed(skill_id)


func _on_remove_skill_button_key_pressed(button_key: String) -> void:
	var skill_id: String = str(_get_skill_mapping().get(button_key, ""))
	if skill_id.is_empty():
		return
	_on_remove_skill_pressed(skill_id)


func set_selected_hero(hero: Node) -> void:
	if not is_instance_valid(hero):
		return

	var stats = hero.get("character_stats")

	if stats == null:
		push_warning("O herói selecionado não possui character_stats.")
		return

	character_stats = stats
	tree_class = str(stats.get("hero_class"))

	update_tree()


func _on_skill_pressed(skill_id: String) -> void:

	if not is_instance_valid(character_stats):
		return

	if character_stats.has_skill(skill_id):
		print("SKILL JÁ APRENDIDA: ", skill_id)
		return

	if not character_stats.can_unlock_skill(skill_id):
		print("NÃO É POSSÍVEL APRENDER: ", skill_id)
		return

	if character_stats.learn_skill(skill_id):
		print("SKILL COMPRADA: ", skill_id)

	update_tree()


# =========================================================
# INVESTIR PONTO NA PROGRESSÃO
# =========================================================

func _on_progress_button_pressed() -> void:

	if not is_instance_valid(character_stats):
		return

	if character_stats.unlocked_stage >= 2:
		return

	if character_stats.invest_in_skill_stage():
		print(
			"PROGRESSO: ",
			character_stats.stage_progress,
			"/5"
		)

		print(
			"ESTÁGIO DESBLOQUEADO: ",
			character_stats.unlocked_stage
		)

	update_tree()


# =========================================================
# FECHAR INTERFACE
# =========================================================

func _on_close_pressed() -> void:
	hide()


func _on_add_skill_pressed(skill_id: String) -> void:
	if not is_instance_valid(character_stats):
		return

	if not character_stats.has_skill(skill_id):
		return

	if skill_id in character_stats.skill_order:
		return

	pending_skill_id = skill_id
	pending_action = "add"

	skill_change_dialog.dialog_text = "Adicionar esta habilidade à sequência? A alteração será aplicada na próxima rodada, quando o mapa for carregado novamente."
	skill_change_dialog.popup_centered()


func _on_remove_skill_pressed(skill_id: String) -> void:
	if not is_instance_valid(character_stats):
		return

	if skill_id not in character_stats.skill_order:
		return

	pending_skill_id = skill_id
	pending_action = "remove"

	skill_change_dialog.dialog_text = "Remover esta habilidade da sequência? A alteração será aplicada na próxima rodada, quando o mapa for carregado novamente."
	skill_change_dialog.popup_centered()


func _on_skill_change_confirmed() -> void:
	if not is_instance_valid(character_stats):
		return

	match pending_action:
		"add":
			character_stats.add_skill_to_order(pending_skill_id)

		"remove":
			character_stats.remove_skill_from_order(pending_skill_id)

	pending_skill_id = ""
	pending_action = ""

	update_tree()


func update_skill_slot_buttons(
	skill_id: String,
	add_button: TextureButton,
	remove_button: TextureButton
) -> void:

	var learned: bool = character_stats.has_skill(skill_id)
	var equipped: bool = skill_id in character_stats.skill_order

	add_button.visible = learned and not equipped
	remove_button.visible = learned and equipped


func get_skill_icons(skill_id: String) -> Dictionary:
	var skill_data: Dictionary = SkillTree.get_skill(skill_id)

	if skill_data.is_empty():
		return {}

	var skill_scene: PackedScene = skill_data.get("scene") as PackedScene

	if skill_scene == null:
		return {}

	var skill_instance = skill_scene.instantiate()

	var icons := {
		"normal": skill_instance.get("icon"),
		"disabled": skill_instance.get("disabled_icon")
	}

	skill_instance.free()

	return icons
