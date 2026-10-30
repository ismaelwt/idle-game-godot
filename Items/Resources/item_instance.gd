
extends Resource
class_name ItemInstance

@export_category("Identificação")
@export var instance_id: String = ""
@export var item_base: ItemBase

@export_category("Equipamento Gerado")
@export var item_level: int = 1
@export var generated_rarity: ItemBase.Rarity = ItemBase.Rarity.COMMON
@export var item_value: int = 10

@export_category("Atributos Sorteados")
@export var strength_bonus: int = 0
@export var agility_bonus: int = 0
@export var intelligence_bonus: int = 0
@export var vitality_bonus: int = 0
@export var max_mana_bonus: int = 0
@export var physical_damage_bonus: int = 0
@export var magic_damage_bonus: int = 0
@export var weapon_damage: float = 0.0
@export var critical_chance_bonus: float = 0.0
@export var critical_damage_bonus: float = 0.0
@export var physical_defense_bonus: int = 0
@export var magic_defense_bonus: int = 0
@export var magic_power_bonus: float = 0.0
@export var life_steal_bonus: float = 0.0
@export var mana_steal_bonus: float = 0.0

@export_category("Efeito da Gema")
@export var gem_effect: ItemBase.GemEffect = ItemBase.GemEffect.NONE
@export var gem_effect_value: float = 0.0

@export_category("Encantamentos")
@export_range(0, 2, 1) var enchantment_slots: int = 0
@export var installed_enchantments: Array[Resource] = []
