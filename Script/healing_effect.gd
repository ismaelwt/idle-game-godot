
extends Node3D

@export_category("Skill")
@export var icon: Texture2D
@export var disabled_icon: Texture2D

@export var cooldown: float = 20.0
@export var mana_cost: float = 50.0
@export var healing_amount: float = 12.0
@export var duration: float = 8.0


func get_description() -> String:
	return "HEALING\nHEAL: %.0f HP\nCOST: %.0f\nCooldown: %.1f s" % [
		healing_amount,
		mana_cost,
		cooldown
	]


func _ready():
	var mesh = get_node_or_null("MeshInstance3D")

	if mesh:
		print("=== HEALING EFFECT ===")
		print("Mesh encontrado: ", mesh)
		print("Material: ", mesh.material_override)
	else:
		print("ERRO: MeshInstance3D não encontrado!")
