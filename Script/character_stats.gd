extends Node

signal level_up_occurred
signal attributes_changed

@export_category("Identidade do Herói")
@export var hero_id: String = "mage"
@export_enum("Mage", "Knight") var hero_class: String = "Mage"

@onready var inventory: Inventory = get_tree().current_scene.find_child("Inventory", true, false)

@export_category("Experiência")
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next_level: int = 100
@export var gold: int = 0

@export_category("Progressão da Árvore")
@export var stage_progress: int = 0
@export var unlocked_stage: int = 0

const POINTS_PER_STAGE: int = 5

@export_category("Skills")
var unlocked_skills: Array[String] = []
var skill_order: Array[String] = []

@export_category("Pontos Disponíveis")
@export var attribute_points: int = 0
@export var skill_points: int = 0


@export_category("Atributos")
@export var strength: int = 5
@export var agility: int = 5
@export var intelligence: int = 5
@export var vitality: int = 5


@export_category("Mana")
@export var base_max_mana: float = 100.0
var max_mana: float:
	get:
		return maxf(0.0, base_max_mana + get_equipment_bonus("max_mana"))
@export var mana_regen_interval: float = 2.0
@export var base_mana_regeneration: float = 2.0
@export var mana_regeneration_per_int: float = 0.1

var mana: float
var mana_regen_timer: float = 0.0


@export_category("Bônus de Dano")
@export var magic_damage_per_int: float = 0.2

@export_category("Basic Attack")
@export var basic_attack_level: int = 0


func _ready():

	mana = max_mana
	mana_regen_timer = 0.0
	
	if is_instance_valid(inventory):
		if not inventory.equipment_changed.is_connected(_on_equipment_changed):
			inventory.equipment_changed.connect(_on_equipment_changed)


func _process(delta):

	if mana >= max_mana:
		mana_regen_timer = 0.0
		return

	mana_regen_timer += delta

	if mana_regen_timer >= mana_regen_interval:

		mana_regen_timer -= mana_regen_interval

		var regeneration = get_mana_regeneration()

		restore_mana(regeneration)


func add_xp(amount: int):

	xp += amount

	print("XP recebida: ", amount)
	print("XP atual: ", xp, "/", xp_to_next_level)

	if xp >= xp_to_next_level:
		level_up()


func level_up():

	xp -= xp_to_next_level
	level += 1
	
	mana = min(
		mana + max_mana * 0.30,
		max_mana
	)
	
	xp_to_next_level = int(xp_to_next_level * 1.2)

	attribute_points += 1
	skill_points += 1

	print("=== LEVEL UP ===")
	print("Novo nível: ", level)
	print("XP para próximo nível: ", xp_to_next_level)
	print("Pontos de atributo disponíveis: ", attribute_points)
	print("Pontos de skill disponíveis: ", skill_points)

	level_up_occurred.emit()


func add_attribute_point(attribute: String):

	if attribute_points <= 0:

		print("Nenhum ponto de atributo disponível.")
		return

	match attribute:

		"strength":
			strength += 1

		"agility":
			agility += 1

		"intelligence":
			intelligence += 1

		"vitality":
			vitality += 1

		_:
			print("Atributo inválido.")
			return

	attribute_points -= 1

	attributes_changed.emit()

	print(
		"Atributo aumentado: ",
		attribute
	)

	print(
		"FOR: ", strength,
		" | AGI: ", agility,
		" | INT: ", intelligence,
		" | VIT: ", vitality
	)


func use_skill_point():

	if skill_points <= 0:

		print("Nenhum ponto de skill disponível.")
		return

	skill_points -= 1

	print("Ponto de skill utilizado.")
	print("Pontos de skill restantes: ", skill_points)


func use_mana(amount: float):

	mana -= amount
	mana = max(mana, 0.0)

	print(
		"Mana usada: ",
		amount
	)

	print(
		"Mana atual: ",
		mana,
		"/",
		max_mana
	)


func restore_mana(amount: float):

	mana += amount
	mana = min(mana, max_mana)


func get_mana_regeneration() -> float:

	var intelligence_bonus = max(
		get_total_intelligence() - 5,
		0
	) * mana_regeneration_per_int

	return base_mana_regeneration + intelligence_bonus


func add_gold(amount: int):

	gold += amount

	print(
		"Gold recebido: ",
		amount
	)

	print(
		"Gold atual: ",
		gold
	)

func has_skill(skill_id: String) -> bool:

	return skill_id in unlocked_skills


func unlock_skill(skill_id: String):

	if has_skill(skill_id):
		return

	unlocked_skills.append(skill_id)

	print("SKILL DESBLOQUEADA: ", skill_id)

func can_unlock_skill(skill_id: String) -> bool:

	if not SkillTree.has_skill(skill_id):
		return false

	# Normaliza a classe para "mage" ou "knight".
	# A SkillTree deve ter skill_belongs_to_class().
	if not SkillTree.skill_belongs_to_class(
		skill_id,
		hero_class.to_lower()
	):
		return false

	return SkillTree.can_learn(
		self,
		skill_id
	)


func learn_skill(skill_id: String) -> bool:

	if not can_unlock_skill(skill_id):
		print(
			"NÃO PODE DESBLOQUEAR: ",
			skill_id,
			" | HERÓI: ",
			hero_id,
			" | CLASSE: ",
			hero_class
		)
		return false

	var skill_data: Dictionary = SkillTree.get_skill(skill_id)
	var cost: int = int(skill_data.get("cost", 0))

	if cost <= 0 or skill_points < cost:
		return false

	skill_points -= cost
	unlock_skill(skill_id)

	# A skill é aprendida, mas não entra automaticamente
	# na sequência de execução.

	SaveManager.save_character(self, inventory, hero_id)

	print(
		"SKILL APRENDIDA: ",
		skill_id,
		" | HERÓI: ",
		hero_id,
		" | CLASSE: ",
		hero_class,
		" | CUSTO: ",
		cost,
		" | SKILL POINTS RESTANTES: ",
		skill_points
	)

	print("ROTAÇÃO ATUAL: ", skill_order)

	return true


func set_skill_order(order: Array[String]):

	skill_order = order.duplicate()

	SaveManager.save_character(self, inventory, hero_id)

	print(
		"NOVA ORDEM DE SKILLS: ",
		skill_order
	)

func add_skill_to_order(skill_id: String) -> bool:

	if not has_skill(skill_id):

		print(
			"SKILL NÃO APRENDIDA: ",
			skill_id
		)

		return false

	if skill_id in skill_order:

		print(
			"SKILL JÁ ESTÁ NA ORDEM: ",
			skill_id
		)

		return false

	skill_order.append(skill_id)

	SaveManager.save_character(self, inventory, hero_id)

	print(
		"SKILL ADICIONADA À ROTAÇÃO: ",
		skill_id
	)

	print(
		"ORDEM ATUAL: ",
		skill_order
	)

	return true


func remove_skill_from_order(skill_id: String) -> bool:

	if skill_id not in skill_order:

		return false

	skill_order.erase(skill_id)

	SaveManager.save_character(self, inventory, hero_id)

	print(
		"SKILL REMOVIDA DA ROTAÇÃO: ",
		skill_id
	)

	print(
		"ORDEM ATUAL: ",
		skill_order
	)

	return true


func move_skill_in_order(
	skill_id: String,
	new_position: int
) -> bool:

	var old_position = skill_order.find(skill_id)

	if old_position == -1:
		return false

	new_position = clamp(
		new_position,
		0,
		skill_order.size() - 1
	)

	skill_order.erase(skill_id)
	skill_order.insert(
		new_position,
		skill_id
	)

	SaveManager.save_character(self, inventory, hero_id)

	print(
		"NOVA ORDEM: ",
		skill_order
	)

	return true

func upgrade_basic_attack() -> bool:

	if skill_points <= 0:
		print("NENHUM SKILL POINT DISPONÍVEL")
		return false

	skill_points -= 1
	basic_attack_level += 1

	SaveManager.save_character(self, inventory, hero_id)

	print(
		"=== BASIC ATTACK EVOLUÍDO ===",
		" | NÍVEL: ", basic_attack_level,
		" | BÔNUS DE DANO: +", basic_attack_level,
		" | SP RESTANTES: ", skill_points
	)

	return true


func invest_in_skill_stage() -> bool:
	if skill_points <= 0:
		return false

	if unlocked_stage >= 2:
		return false

	skill_points -= 1
	stage_progress = mini(stage_progress + 3, 100)

	if unlocked_stage == 0 and stage_progress >= 15.0:
		unlocked_stage = 1
		print("ESTÁGIO 1 DESBLOQUEADO")

	elif unlocked_stage == 1 and stage_progress >= 36.0:
		unlocked_stage = 2
		print("ESTÁGIO 2 DESBLOQUEADO")

	SaveManager.save_character(self, inventory, hero_id)
	return true


func get_equipment_bonus(stat_name: String) -> float:
	if not is_instance_valid(inventory):
		return 0.0

	var total: float = 0.0

	for item in inventory.get_equipped_items(hero_id).values():
		if not item is ItemInstance or item.item_base == null:
			continue

		match stat_name:
			"strength":
				total += float(item.strength_bonus)
			"agility":
				total += float(item.agility_bonus)
			"intelligence":
				total += float(item.intelligence_bonus)
			"vitality":
				total += float(item.vitality_bonus)
			"max_mana":
				total += float(item.max_mana_bonus)
			"physical_damage":
				total += float(item.physical_damage_bonus)
			"magic_damage":
				total += float(item.magic_damage_bonus)
			"physical_defense":
				total += float(item.physical_defense_bonus)
			"magic_defense":
				total += float(item.magic_defense_bonus)
			"magic_power":
				total += item.magic_power_bonus
			"life_steal":
				total += item.life_steal_bonus
			"mana_steal":
				total += item.mana_steal_bonus
			"critical_chance":
				total += item.critical_chance_bonus
			"critical_damage":
				total += item.critical_damage_bonus
			"weapon_damage":
				if item.item_base.item_type == ItemBase.ItemType.WEAPON:
					total += item.weapon_damage

		# As gemas instaladas no equipamento também concedem atributos.
		for enchantment in item.installed_enchantments:
			if not enchantment is ItemInstance:
				continue

			var gem_value: float = enchantment.gem_effect_value
			match enchantment.gem_effect:
				ItemBase.GemEffect.STRENGTH:
					if stat_name == "strength":
						total += gem_value
				ItemBase.GemEffect.AGILITY:
					if stat_name == "agility":
						total += gem_value
				ItemBase.GemEffect.INTELLIGENCE:
					if stat_name == "intelligence":
						total += gem_value
				ItemBase.GemEffect.VITALITY:
					if stat_name == "vitality":
						total += gem_value
				ItemBase.GemEffect.MAX_MANA:
					if stat_name == "max_mana":
						total += gem_value
				ItemBase.GemEffect.PHYSICAL_DAMAGE:
					if stat_name == "physical_damage":
						total += gem_value
				ItemBase.GemEffect.MAGIC_DAMAGE:
					if stat_name == "magic_damage":
						total += gem_value
				ItemBase.GemEffect.DEFENSE:
					# Compatibilidade para gemas antigas de defesa genérica.
					if stat_name == "physical_defense" or stat_name == "magic_defense":
						total += gem_value
				ItemBase.GemEffect.PHYSICAL_DEFENSE:
					if stat_name == "physical_defense":
						total += gem_value
				ItemBase.GemEffect.MAGIC_DEFENSE:
					if stat_name == "magic_defense":
						total += gem_value
				ItemBase.GemEffect.MAGIC_POWER:
					if stat_name == "magic_power":
						total += gem_value
				ItemBase.GemEffect.LIFE_STEAL:
					if stat_name == "life_steal":
						total += gem_value
				ItemBase.GemEffect.MANA_STEAL:
					if stat_name == "mana_steal":
						total += gem_value

	return total


func get_total_strength() -> int:
	return strength + roundi(get_equipment_bonus("strength"))


func get_total_agility() -> int:
	return agility + roundi(get_equipment_bonus("agility"))


func get_total_intelligence() -> int:
	return intelligence + roundi(get_equipment_bonus("intelligence"))


func get_total_vitality() -> int:
	return vitality + roundi(get_equipment_bonus("vitality"))


const DEFENSE_K: float = 200.0
const BASE_CRITICAL_CHANCE: float = 1.0
const CRITICAL_DAMAGE_MULTIPLIER: float = 1.5
const AGILITY_POINTS_PER_CRIT_STEP: int = 5
const CRIT_PER_AGILITY_STEP: float = 0.5
const AGILITY_POINTS_PER_ATTACK_STEP: int = 5
const BASIC_ATTACK_INTERVAL_REDUCTION_PER_STEP: float = 0.05
const BASIC_ATTACK_MIN_INTERVAL_MULTIPLIER: float = 0.10


func get_physical_damage_bonus() -> int:
	var strength_steps := maxi(0, int(floor(float(get_total_strength() - 5) / 5.0)))
	return strength_steps + roundi(get_equipment_bonus("physical_damage"))


func get_critical_chance() -> float:
	var agility_steps := maxi(0, int(floor(float(get_total_agility() - 5) / float(AGILITY_POINTS_PER_CRIT_STEP))))
		return minf(
		100.0,
		BASE_CRITICAL_CHANCE
		+ agility_steps * CRIT_PER_AGILITY_STEP
		+ get_equipment_bonus("critical_chance")
	)


func get_critical_damage_multiplier() -> float:
	return maxf(
		1.0,
		CRITICAL_DAMAGE_MULTIPLIER
		+ get_equipment_bonus("critical_damage") / 100.0
	)


func apply_critical_damage(base_damage: float) -> float:
	if randf() * 100.0 < get_critical_chance():
		return base_damage * get_critical_damage_multiplier()
	return base_damage


func get_weapon_damage_bonus() -> float:
	return maxf(0.0, get_equipment_bonus("weapon_damage"))


func get_basic_attack_interval_multiplier() -> float:
	var agility_steps := maxi(0, int(floor(float(get_total_agility() - 5) / float(AGILITY_POINTS_PER_ATTACK_STEP))))
	return maxf(BASIC_ATTACK_MIN_INTERVAL_MULTIPLIER, 1.0 - agility_steps * BASIC_ATTACK_INTERVAL_REDUCTION_PER_STEP)


func calculate_damage_after_defense(damage: float, damage_type: String = "physical") -> float:
	var defense_value := 0.0
	if damage_type == "magic":
		defense_value = get_equipment_bonus("magic_defense")
	else:
		defense_value = get_equipment_bonus("physical_defense")
	defense_value = maxf(defense_value, 0.0)
	return maxf(damage, 0.0) * DEFENSE_K / (DEFENSE_K + defense_value)


func get_magic_bonus() -> float:
	var total_intelligence := get_total_intelligence()
	return (
		(total_intelligence - 5) * magic_damage_per_int
		+ get_equipment_bonus("magic_damage")
		+ get_weapon_damage_bonus()
	)


func get_magic_damage_multiplier() -> float:
	return maxf(0.0, 1.0 + get_equipment_bonus("magic_power") / 100.0)


func get_life_steal() -> float:
	return maxf(0.0, get_equipment_bonus("life_steal"))


func get_mana_steal() -> float:
	return maxf(0.0, get_equipment_bonus("mana_steal"))


func apply_on_hit_effects(damage_dealt: float) -> void:
	if damage_dealt <= 0.0:
		return

	var hero := get_parent()
	if not is_instance_valid(hero) or bool(hero.get("dead")):
		return

	var life_steal_amount := damage_dealt * get_life_steal() / 100.0
	var current_health = hero.get("health")
	var maximum_health = hero.get("max_health")

	if life_steal_amount > 0.0 and current_health != null and maximum_health != null:
		hero.set(
			"health",
			minf(float(current_health) + life_steal_amount, float(maximum_health))
		)

	var mana_steal_amount := damage_dealt * get_mana_steal() / 100.0
	if mana_steal_amount > 0.0:
		restore_mana(mana_steal_amount)


func get_max_health_bonus() -> int:
	return (get_total_vitality() - 5) * 10


func _on_equipment_changed() -> void:
	mana = minf(mana, max_mana)
	attributes_changed.emit()

func is_critical_hit() -> bool:
	return randf() * 100.0 < get_critical_chance()
