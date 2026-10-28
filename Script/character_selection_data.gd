extends Node
## Estado centralizado da seleção do personagem principal.
## IDs canônicos: "mage", "knight" ou o ID de outro herói registrado.

const DEFAULT_CHARACTER_ID: String = "mage"

var selected_character: String = DEFAULT_CHARACTER_ID


func get_selected_character_id() -> String:
	return normalize_hero_id(selected_character)


func set_selected_character(hero_id: String) -> void:
	var normalized_id := normalize_hero_id(hero_id)
	if normalized_id.is_empty():
		push_warning("CharacterSelectionData: ID de personagem vazio.")
		return

	selected_character = normalized_id


static func normalize_hero_id(hero_id: String) -> String:
	var normalized_id := hero_id.strip_edges().to_lower()

	# Compatibilidade com saves/cenas que ainda usam o ID antigo do Mage.
	if normalized_id == "player":
		return "mage"

	return normalized_id
