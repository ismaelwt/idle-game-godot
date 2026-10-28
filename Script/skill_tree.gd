
extends Node

# =========================================================
# DEFINIÇÃO DA ÁRVORE DE SKILLS
# =========================================================
# hero_class:
#   "mage"   = habilidades do Mago
#   "knight" = habilidades do Knight
#
# As habilidades existentes do Mago foram preservadas.
# As habilidades do Knight serão adicionadas quando suas
# cenas estiverem definidas.
# =========================================================

const SKILLS := {
	# =====================================================
	# MAGO - ESTÁGIO 1
	# =====================================================

	"fireball": {
		"name": "Fireball",
		"hero_class": "mage",
		"scene": preload("res://Scenes/fireball_v1.tscn"),
		"cost": 1,
		"stage": 1,
		"prerequisites": [],
		"button": "skill1_nv1"
	},

	"energy_ball": {
		"name": "Energy Ball",
		"hero_class": "mage",
		"scene": preload("res://Scenes/energy_ball.tscn"),
		"cost": 1,
		"stage": 1,
		"prerequisites": ["fireball"],
		"button": "skill2_nv1"
	},

	"damage_buff": {
		"name": "Damage Buff",
		"hero_class": "mage",
		"scene": preload("res://Scenes/damage_buff.tscn"),
		"cost": 1,
		"stage": 1,
		"prerequisites": [],
		"button": "skill3_nv1"
	},

	# =====================================================
	# MAGO - ESTÁGIO 2
	# =====================================================

	"heal": {
		"name": "Healing Buff",
		"hero_class": "mage",
		"scene": preload("res://Scenes/healing_effect.tscn"),
		"cost": 1,
		"stage": 2,
		"prerequisites": [
			"fireball",
			"energy_ball",
			"damage_buff"
		],
		"button": "skill1_nv2"
	},

	"thunderstorm": {
		"name": "Thunderstorm",
		"hero_class": "mage",
		"scene": preload("res://Scenes/thunderstorm.tscn"),
		"cost": 1,
		"stage": 2,
		"prerequisites": [
			"fireball",
			"energy_ball",
			"damage_buff"
		],
		"button": "skill2_nv2"
	},

	# =====================================================
	# KNIGHT
	# =====================================================
	# Adicionaremos aqui as cinco habilidades físicas,
	# usando IDs exclusivos e cenas próprias.
	
	"frenesi": {
		"name": "Frenesi",
		"hero_class": "knight",
		"scene": preload("res://Scenes/damage_buff.tscn"),
		"cost": 1,
		"stage": 1,
		"prerequisites": [],
		"button": "skill1_nv1"
	},
}


var description_cache: Dictionary = {}


# =========================================================
# VERIFICA SE A SKILL EXISTE
# =========================================================

func has_skill(skill_id: String) -> bool:
	return SKILLS.has(skill_id)


# =========================================================
# RETORNA OS DADOS DA SKILL
# =========================================================

func get_skill(skill_id: String) -> Dictionary:
	if not SKILLS.has(skill_id):
		return {}

	return SKILLS[skill_id]


# =========================================================
# RETORNA AS SKILLS DE UMA CLASSE
# =========================================================

func get_skills_for_class(hero_class: String) -> Dictionary:
	var result: Dictionary = {}

	for skill_id in SKILLS:
		var skill_data: Dictionary = SKILLS[skill_id]

		if skill_data.get("hero_class", "") == hero_class.to_lower():
			result[skill_id] = skill_data

	return result


# =========================================================
# VERIFICA SE A SKILL PERTENCE À CLASSE
# =========================================================

func skill_belongs_to_class(
	skill_id: String,
	hero_class: String
) -> bool:
	var skill_data: Dictionary = get_skill(skill_id)

	if skill_data.is_empty():
		return false

	return skill_data.get("hero_class", "") == hero_class.to_lower()


# =========================================================
# VERIFICA OS PRÉ-REQUISITOS
# =========================================================

func prerequisites_met(
	character_stats,
	skill_id: String
) -> bool:
	if not SKILLS.has(skill_id):
		return false

	var skill_data: Dictionary = SKILLS[skill_id]
	var prerequisites: Array = skill_data["prerequisites"]

	for prerequisite in prerequisites:
		if not character_stats.has_skill(prerequisite):
			return false

	return true


# =========================================================
# VERIFICA SE O ESTÁGIO ESTÁ DESBLOQUEADO
# =========================================================

func stage_unlocked(
	character_stats,
	skill_id: String
) -> bool:
	if not SKILLS.has(skill_id):
		return false

	var skill_data: Dictionary = SKILLS[skill_id]
	var required_stage: int = skill_data["stage"]

	return character_stats.unlocked_stage >= required_stage


# =========================================================
# VERIFICA SE PODE APRENDER A SKILL
# =========================================================

func can_learn(
	character_stats,
	skill_id: String
) -> bool:
	if not SKILLS.has(skill_id):
		return false

	if character_stats.has_skill(skill_id):
		return false

	var skill_data: Dictionary = SKILLS[skill_id]
	var cost: int = skill_data["cost"]

	if character_stats.skill_points < cost:
		return false

	if not stage_unlocked(character_stats, skill_id):
		return false

	if not prerequisites_met(character_stats, skill_id):
		return false

	return true


# =========================================================
# DESCRIÇÃO DA SKILL
# =========================================================

func get_skill_description(skill_id: String) -> String:
	if description_cache.has(skill_id):
		return description_cache[skill_id]

	var skill_data: Dictionary = get_skill(skill_id)

	if skill_data.is_empty():
		return ""

	var skill_scene: PackedScene = skill_data.get("scene")

	if skill_scene == null:
		return ""

	var skill_instance = skill_scene.instantiate()

	if not skill_instance.has_method("get_description"):
		skill_instance.free()
		return ""

	var description: String = skill_instance.get_description()

	skill_instance.free()

	description_cache[skill_id] = description

	return description
