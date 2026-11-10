extends Control

@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar

var loading_path: String = ""
var overlay_mode: bool = false
var progress_value: float = 0.0


func _ready() -> void:
	progress_bar.value = progress_value

	# No modo overlay, a GameSession controla o início e o fim do loading.
	if overlay_mode:
		return

	loading_path = SceneLoader.target_scene_path
	if loading_path.is_empty():
		push_error("Loading: nenhum caminho de cena foi definido.")
		return

	progress_bar.value = 0.0
	await get_tree().process_frame
	var destination_path := loading_path
	if loading_path.begins_with("res://Scenes/level_"):
		SceneLoader.initial_level_path = loading_path
		destination_path = SceneLoader.GAME_SESSION_PATH
	var packed_scene := ResourceLoader.load(destination_path) as PackedScene
	if packed_scene == null:
		push_error("Loading: não foi possível carregar " + destination_path)
		return
	progress_bar.value = 100.0
	await get_tree().process_frame
	get_tree().change_scene_to_packed(packed_scene)


func set_progress(value: float) -> void:
	progress_value = clampf(value, 0.0, 100.0)
	if is_instance_valid(progress_bar):
		progress_bar.value = progress_value
