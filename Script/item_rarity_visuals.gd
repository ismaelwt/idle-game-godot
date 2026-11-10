extends RefCounted
class_name ItemRarityVisuals

const GLOW_SHADER: Shader = preload("res://Shaders/item_rarity_glow.gdshader")


static func create_material(item: ItemInstance) -> ShaderMaterial:
	if item == null or item.item_base == null:
		return null

	var rarity_names: Array = ItemBase.Rarity.keys()
	if item.generated_rarity < 0 or item.generated_rarity >= rarity_names.size():
		return null

	var rarity_name := str(rarity_names[item.generated_rarity]).to_lower()
	var glow_color := _get_rarity_color(rarity_name)
	if glow_color.a <= 0.0:
		return null

	var material := ShaderMaterial.new()
	material.shader = GLOW_SHADER
	material.set_shader_parameter("rarity_color", glow_color)
	return material


static func _get_rarity_color(rarity_name: String) -> Color:
	if rarity_name.contains("uncommon") or rarity_name.contains("unusual") or rarity_name.contains("incomum"):
		return Color("#62ed83")
	if rarity_name.contains("rare") or rarity_name.contains("raro"):
		return Color("#45a9ff")
	if rarity_name.contains("epic") or rarity_name.contains("épico") or rarity_name.contains("epico"):
		return Color("#bd65ff")
	if rarity_name.contains("legendary") or rarity_name.contains("lendário") or rarity_name.contains("lendario"):
		return Color("#ffb52e")
	if rarity_name.contains("mythic") or rarity_name.contains("mítico") or rarity_name.contains("mitico"):
		return Color("#ff493d")
	return Color(0.0, 0.0, 0.0, 0.0)


static func apply_to_slot(slot: Control, item: ItemInstance) -> void:
	if not is_instance_valid(slot):
		return

	var overlay := slot.get_node_or_null("RarityGlowBorder") as ColorRect
	var material := create_material(item)

	if material == null:
		if is_instance_valid(overlay):
			overlay.visible = false
		return

	if not is_instance_valid(overlay):
		overlay = ColorRect.new()
		overlay.name = "RarityGlowBorder"
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color.WHITE
		slot.add_child(overlay)

	# Usa z-index absoluto: não herda o z_index elevado do InventoryControl.
	overlay.z_as_relative = false
	overlay.z_index = 0
	overlay.material = material
	overlay.visible = true
