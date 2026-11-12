extends Node

## Centraliza mensagens de depuração.
## Os logs são ignorados em builds de release.
func d(...messages: Array) -> void:
	if not OS.is_debug_build():
		return

	var parts := PackedStringArray()
	for message in messages:
		parts.append(str(message))

	print(" ".join(parts))
