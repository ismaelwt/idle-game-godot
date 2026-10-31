
extends RefCounted
class_name ItemGenerator

@export_category("Nível dos Itens")
@export_range(0, 50, 1) var levels_below_player: int = 4
@export_range(0, 50, 1) var levels_above_player: int = 4

@export_category("Escalonamento")
@export_range(0.0, 1.0, 0.01) var scaling_per_level: float = 0.05
@export_range(0.0, 1.0, 0.001) var weapon_damage_scaling_per_level: float = 0.105263


func generate_item(
	base: ItemBase,
	player_level: int = 1,
	levels_below_override: int = -1,
	levels_above_override: int = -1
) -> ItemInstance:
	if base == null:
		push_error("ItemGenerator: ItemBase inválido.")
		return null

	var item := ItemInstance.new()

	item.item_base = base
	item.instance_id = str(ResourceUID.create_id())
	item.generated_rarity = base.rarity
	item.item_value = base.get_item_value()

	# Sorteia o nível do item conforme o nível do jogador.
	var character_level := maxi(1, player_level)
	var levels_below := levels_below_player if levels_below_override < 0 else levels_below_override
	var levels_above := levels_above_player if levels_above_override < 0 else levels_above_override
	var min_level := maxi(1, character_level - levels_below)
	var max_level := maxi(min_level, character_level + levels_above)

	item.item_level = randi_range(min_level, max_level)

	# Escalonamento linear: 5% por nível acima do nível 1.
	var multiplier: float = 1.0 + (
		float(item.item_level - 1) * scaling_per_level
	)

	# Dano base da arma: escala linearmente com o nível do item.
	# Com base 5, uma arma nível 20 chega a aproximadamente 15 de dano.
	if base.item_type == ItemBase.ItemType.WEAPON:
		item.weapon_damage = base.weapon_damage * (
			1.0 + float(item.item_level - 1) * weapon_damage_scaling_per_level
		)

	# Gemas mantêm sua geração própria.
	if base.item_type == ItemBase.ItemType.GEM:
		item.gem_effect = base.gem_effect

		if base.gem_effect != ItemBase.GemEffect.NONE:
			item.gem_effect_value = randf_range(
				base.gem_effect_min,
				base.gem_effect_max
			)

		item.enchantment_slots = 0
		item.installed_enchantments.clear()
		return item

	# Define quantos atributos o item poderá receber.
	var attribute_count := get_attribute_count(item.generated_rarity)

	# Monta a lista apenas com atributos configurados no ItemBase.
	var available_attributes: Array[StringName] = []

	if base.strength_min != 0 or base.strength_max != 0:
		available_attributes.append(&"strength")

	if base.agility_min != 0 or base.agility_max != 0:
		available_attributes.append(&"agility")

	if base.intelligence_min != 0 or base.intelligence_max != 0:
		available_attributes.append(&"intelligence")

	if base.vitality_min != 0 or base.vitality_max != 0:
		available_attributes.append(&"vitality")

	if base.max_mana_min != 0 or base.max_mana_max != 0:
		available_attributes.append(&"max_mana")

	if base.physical_damage_min != 0 or base.physical_damage_max != 0:
		available_attributes.append(&"physical_damage")

	if base.magic_damage_min != 0 or base.magic_damage_max != 0:
		available_attributes.append(&"magic_damage")

	if base.physical_defense_min != 0 or base.physical_defense_max != 0:
		available_attributes.append(&"physical_defense")
	if base.magic_defense_min != 0 or base.magic_defense_max != 0:
		available_attributes.append(&"magic_defense")

	if base.magic_power_min != 0.0 or base.magic_power_max != 0.0:
		available_attributes.append(&"magic_power")

	if base.life_steal_min != 0.0 or base.life_steal_max != 0.0:
		available_attributes.append(&"life_steal")
	if base.mana_steal_min != 0.0 or base.mana_steal_max != 0.0:
		available_attributes.append(&"mana_steal")

	# Crítico pode ser sorteado em armas, luvas, anéis e cintos.
	# Amuletos (necklaces) seguem a regra dos demais equipamentos sem crítico.
	var can_roll_critical := base.item_type in [
		ItemBase.ItemType.WEAPON,
		ItemBase.ItemType.GLOVES,
		ItemBase.ItemType.RING,
		ItemBase.ItemType.BELT,
		ItemBase.ItemType.ACCESSORY
	]
	if can_roll_critical:
		if base.critical_chance_min != 0.0 or base.critical_chance_max != 0.0:
			available_attributes.append(&"critical_chance")
		if base.critical_damage_min != 0.0 or base.critical_damage_max != 0.0:
			available_attributes.append(&"critical_damage")

	# Começa com todos os bônus zerados.
	item.strength_bonus = 0
	item.agility_bonus = 0
	item.intelligence_bonus = 0
	item.vitality_bonus = 0
	item.max_mana_bonus = 0
	item.physical_damage_bonus = 0
	item.magic_damage_bonus = 0
	item.physical_defense_bonus = 0
	item.magic_defense_bonus = 0
	item.magic_power_bonus = 0.0
	item.life_steal_bonus = 0.0
	item.mana_steal_bonus = 0.0
	item.critical_chance_bonus = 0.0
	item.critical_damage_bonus = 0.0

	# Sorteia os atributos sem repetir nenhum.
	var count := mini(attribute_count, available_attributes.size())

	for i in range(count):
		var index := randi_range(0, available_attributes.size() - 1)
		var attribute: StringName = available_attributes[index]
		available_attributes.remove_at(index)

		match attribute:
			&"strength":
				item.strength_bonus = roundi(
					randi_range(base.strength_min, base.strength_max) * multiplier
				)
			&"agility":
				item.agility_bonus = roundi(
					randi_range(base.agility_min, base.agility_max) * multiplier
				)
			&"intelligence":
				item.intelligence_bonus = roundi(
					randi_range(base.intelligence_min, base.intelligence_max) * multiplier
				)
			&"vitality":
				item.vitality_bonus = roundi(
					randi_range(base.vitality_min, base.vitality_max) * multiplier
				)
			&"max_mana":
				item.max_mana_bonus = roundi(
					randi_range(base.max_mana_min, base.max_mana_max) * multiplier
				)
			&"physical_damage":
				item.physical_damage_bonus = roundi(
					randi_range(base.physical_damage_min, base.physical_damage_max) * multiplier
				)
			&"magic_damage":
				item.magic_damage_bonus = roundi(
					randi_range(base.magic_damage_min, base.magic_damage_max) * multiplier
				)
			&"physical_defense":
				item.physical_defense_bonus = roundi(
					randi_range(base.physical_defense_min, base.physical_defense_max) * multiplier
				)
			&"magic_defense":
				item.magic_defense_bonus = roundi(
					randi_range(base.magic_defense_min, base.magic_defense_max) * multiplier
				)
			&"magic_power":
				item.magic_power_bonus = randf_range(
					base.magic_power_min,
					base.magic_power_max
				) * multiplier
			&"life_steal":
				item.life_steal_bonus = randf_range(
					base.life_steal_min,
					base.life_steal_max
				) * multiplier
			&"mana_steal":
				item.mana_steal_bonus = randf_range(
					base.mana_steal_min,
					base.mana_steal_max
				) * multiplier
			&"critical_chance":
				item.critical_chance_bonus = randf_range(
					base.critical_chance_min,
					base.critical_chance_max
				) * multiplier
			&"critical_damage":
				item.critical_damage_bonus = randf_range(
					base.critical_damage_min,
					base.critical_damage_max
				) * multiplier

	# Sorteia os slots de encantamento.
	var min_slots := clampi(base.min_enchantment_slots, 0, 2)
	var max_slots := clampi(base.max_enchantment_slots, min_slots, 2)

	item.enchantment_slots = randi_range(min_slots, max_slots)
	item.installed_enchantments.clear()

	return item


func get_attribute_count(rarity: ItemBase.Rarity) -> int:
	match rarity:
		ItemBase.Rarity.COMMON:
			return 1
		ItemBase.Rarity.UNCOMMON:
			return 2
		ItemBase.Rarity.RARE:
			return 3
		ItemBase.Rarity.EPIC:
			return 4
		ItemBase.Rarity.LEGENDARY:
			return 5

	return 1


func generate_chest_item(
	player_level: int = 1,
	item_class: ItemBase.ItemClass = ItemBase.ItemClass.ALL
) -> ItemInstance:
	var database := ItemDatabase.new()

	var rarity := database.roll_rarity()
	var base := database.get_random_item_by_rarity(rarity, item_class)

	# Se não houver item da raridade sorteada, tenta qualquer item
	# cadastrado, independentemente da classe, para evitar um baú vazio.
	if base == null:
		var class_items := database.get_items_by_class(item_class)
		if not class_items.is_empty():
			base = class_items[randi_range(0, class_items.size() - 1)]

	if base == null:
		push_error(
			"ItemGenerator: não existe item cadastrado para a raridade sorteada."
		)
		return null

	# Recompensas de boss: itens podem vir até 2 níveis abaixo do boss,
	# mas nunca acima do nível dele. O nível do personagem não participa.
	return generate_item(base, player_level, 2, 0)
