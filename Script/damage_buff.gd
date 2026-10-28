extends Node3D

@export_category("Skill")
@export var icon: Texture2D
@export var disabled_icon: Texture2D

func get_description() -> String:
	return "AURA \nADD DMG:  %.1fx\nCOST: %.0f\nTIME ACTIVE: %.0f\nCooldown: %.1f s" % [
		damage_buff_multiplier,
		mana_cost,
		duration,
		cooldown
	]
@export var cooldown: float = 20.0
@export var mana_cost: float = 50.0
@export var duration: float = 25.0
@export var damage_buff_multiplier: float = 1.5

func _ready():

	var mesh = get_node_or_null("MeshInstance3D")

	if mesh:

		print("=== DAMAGE BUFF ===")
		print("Mesh encontrado: ", mesh)
		print("Material: ", mesh.material_override)

		if mesh.material_override:

			print(
				"ShaderMaterial: ",
				mesh.material_override is ShaderMaterial
			)

	else:

		print("ERRO: MeshInstance3D não encontrado!")
