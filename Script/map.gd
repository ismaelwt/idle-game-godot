extends Control

# Fase atual exibida no mapa.
@export var current_stage: int = 1

# Maior fase liberada para toda a party.
var unlocked_level: int = 1

@onready var map_window: MapWindow = $MapWindow
@onready var markers: Control = $MapWindow/Content/Markers
@onready var close_button = $Frame/CloseButton
@onready var pointer: Control = $MapWindow/Content/Markers/Pointer


func _ready() -> void:
	current_stage = detect_current_stage()
	load_campaign_progress()

	print("MAPA | Fase atual: ", current_stage)
	print("MAPA | Maior fase desbloqueada (global): ", unlocked_level)

	# Conecta os botões e atualiza o bloqueio de cada fase.
	for child in markers.get_children():
		if child.name == "Pointer":
			continue

		var button := child as BaseButton
		if button == null:
			continue

		if not child.name.begins_with("Fase"):
			continue

		var stage_text := child.name.trim_prefix("Fase")
		if not stage_text.is_valid_int():
			continue

		var stage := stage_text.to_int()

		# Só permite entrar em fases desbloqueadas globalmente.
		button.disabled = stage > unlocked_level

		var callback := _on_stage_pressed.bind(stage)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)

	update_phase_pointer(current_stage)

	# Centraliza o mapa na fase atual.
	var current := markers.get_node_or_null("Fase%d" % current_stage) as Control
	if current != null:
		map_window.scroll_to_marker(current, false)

	if close_button != null:
		if not close_button.pressed.is_connected(_on_close_pressed):
			close_button.pressed.connect(_on_close_pressed)


func load_campaign_progress() -> void:
	unlocked_level = 1

	# O progresso global da campanha fica em SaveManager.global.
	# Isso evita depender do herói selecionado para desbloquear fases.
	if has_node("/root/SaveManager"):
		var global_data: Dictionary = SaveManager.load_global_data()
		if global_data.has("unlocked_level"):
			unlocked_level = maxi(1, int(global_data["unlocked_level"]))
			return
	else:
		push_warning("MAPA | SaveManager Autoload não encontrado.")

	# Compatibilidade temporária com saves antigos, nos quais o desbloqueio
	# ainda estava salvo dentro de CharacterStats do Player.
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node == null:
		push_warning("MAPA | Progresso global não encontrado; mantendo fase 1 desbloqueada.")
		return

	if not "character_stats" in player_node:
		push_warning("MAPA | O jogador não possui character_stats; mantendo fase 1 desbloqueada.")
		return

	var stats = player_node.character_stats
	if stats != null and "unlocked_level" in stats:
		unlocked_level = maxi(1, int(stats.unlocked_level))
		print("MAPA | Usando unlocked_level legado de CharacterStats: ", unlocked_level)
	else:
		print("MAPA | Nenhum progresso legado encontrado; fase 1 desbloqueada.")


func update_phase_pointer(stage: int) -> void:
	var marker := markers.get_node_or_null("Fase%d" % stage) as TextureButton
	if marker == null:
		push_warning("Marcador da fase %d não encontrado." % stage)
		return

	var target := marker.get_node_or_null("PhasePointerPosition") as Control
	if target == null:
		push_warning("PhasePointerPosition não encontrado na fase %d." % stage)
		return

	# Centro do ponto de referência em coordenadas globais.
	var target_center_global: Vector2 = (
		target.get_global_transform_with_canvas() * (target.size * 0.5)
	)

	# Converte para as coordenadas locais do pai do ponteiro.
	var pointer_parent := pointer.get_parent() as Control
	if pointer_parent == null:
		push_warning("O pai do ponteiro não é um Control.")
		return

	var parent_transform: Transform2D = pointer_parent.get_global_transform_with_canvas()
	var target_center_local: Vector2 = (
		parent_transform.affine_inverse() * target_center_global
	)

	pointer.position = target_center_local - pointer.size * 0.5


func _on_stage_pressed(stage: int) -> void:
	if map_window.just_dragged:
		return

	# Segunda proteção contra acesso a fases bloqueadas.
	if stage > unlocked_level:
		return

	SceneLoader.change_scene("res://Scenes/level_%d.tscn" % stage)


func _on_close_pressed() -> void:
	visible = false


func detect_current_stage() -> int:
	var scene := get_tree().current_scene
	if scene == null:
		push_warning("Não foi possível identificar a cena atual.")
		return current_stage

	var scene_path: String = scene.scene_file_path
	var scene_name: String = scene_path.get_file().get_basename()
	print("MAPA | Cena atual: ", scene_name)

	if scene_name.begins_with("level_"):
		var stage_text := scene_name.trim_prefix("level_")
		if stage_text.is_valid_int():
			return stage_text.to_int()

	push_warning("Cena não corresponde ao padrão level_N: " + scene_name)
	return current_stage
