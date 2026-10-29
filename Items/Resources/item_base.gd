
extends Resource
class_name ItemBase

enum ItemType {
	WEAPON,
	HELMET,
	CHEST,
	GLOVES,
	PANTS,
	BOOTS,
	ACCESSORY,
	GEM
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

enum ItemClass {
	MAGE,
	KNIGHT,
	ARCHER
}

enum GemEffect {
	NONE,
	STRENGTH,
	AGILITY,
	INTELLIGENCE,
	VITALITY,
	MAX_MANA,
	PHYSICAL_DAMAGE,
	MAGIC_DAMAGE,
	DEFENSE,
	MAGIC_POWER
}



@export_category("Identificação")
@export var item_id: StringName
@export var item_name: String = ""
@export_multiline var description: String = ""

@export var icon: Texture2D
@export var icon_slot_1: Texture2D
@export var icon_slot_2: Texture2D

@export_category("Classificação")
@export var item_type: ItemType = ItemType.WEAPON
@export var item_class: ItemClass = ItemClass.MAGE
@export var rarity: Rarity = Rarity.COMMON

@export_category("Nível do Item")
@export_range(1, 100, 1) var item_level: int = 1
@export_range(1, 100, 1) var required_level: int = 1

@export_category("Valor")
@export_range(0, 1000000, 1) var base_value: int = 10


func get_item_value() -> int:
	match rarity:
		Rarity.COMMON:
			return base_value
		Rarity.UNCOMMON:
			return base_value * 2
		Rarity.RARE:
			return base_value * 4
		Rarity.EPIC:
			return base_value * 8
		Rarity.LEGENDARY:
			return base_value * 16

	return base_value

@export_category("Atributos Aleatórios")

@export_group("Força")
@export var strength_min: int = 0
@export var strength_max: int = 0

@export_group("Agilidade")
@export var agility_min: int = 0
@export var agility_max: int = 0

@export_group("Inteligência")
@export var intelligence_min: int = 0
@export var intelligence_max: int = 0

@export_group("Vitalidade")
@export var vitality_min: int = 0
@export var vitality_max: int = 0

@export_group("Mana Máxima")
@export var max_mana_min: int = 0
@export var max_mana_max: int = 0

@export_group("Dano Físico")
@export var physical_damage_min: int = 0
@export var physical_damage_max: int = 0

@export_group("Dano Mágico")
@export var magic_damage_min: int = 0
@export var magic_damage_max: int = 0

@export_group("Defesa Física")
@export var physical_defense_min: int = 0
@export var physical_defense_max: int = 0

@export_group("Defesa Mágica")
@export var magic_defense_min: int = 0
@export var magic_defense_max: int = 0

# Compatibilidade com recursos antigos. Defesa genérica protege contra os dois tipos.
@export_group("Defesa Antiga (Compatibilidade)")
@export var defense_min: int = 0
@export var defense_max: int = 0

@export_group("Poder Mágico (%)")
@export var magic_power_min: float = 0.0
@export var magic_power_max: float = 0.0

@export_category("Encantamento de Gema")
@export var gem_effect: GemEffect = GemEffect.NONE
@export var gem_effect_min: float = 0.0
@export var gem_effect_max: float = 0.0

@export_category("Slots de Encantamento")
@export_range(0, 2, 1) var min_enchantment_slots: int = 0
@export_range(0, 2, 1) var max_enchantment_slots: int = 0
