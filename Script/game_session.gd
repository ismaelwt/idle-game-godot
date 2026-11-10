extends Node

signal level_loaded(level: Node)

@onready var level_container: Node3D = $LevelContainer
@onready var persistent_ui: CanvasLayer = $PersistentUI

var current_level_path: String = ""
var current_level: Node = null
var is_loading_level: bool = false


func _ready() -> void:
	call_deferred("_load_initial_level")


func _load_initial_level() -> void:
	var path := SceneLoader.initial_level_path
	if path.is_empty():
		path = "res://Scenes/level_1.tscn"
	await load_level(path)


func load_level(path: String) -> void:
	if is_loading_level:
		return
	if not path.begins_with("res://Scenes/level_"):
		push_warning("GameSession: caminho de fase inválido: " + path)
		return
	is_loading_level = true
	get_tree().paused = false

	if is_instance_valid(current_level):
		if persistent_ui.has_method("before_level_unload"):
			persistent_ui.call("before_level_unload")
		level_container.remove_child(current_level)
		current_level.queue_free()
		current_level = null

	await get_tree().process_frame
	var packed_scene := ResourceLoader.load(path) as PackedScene
	if packed_scene == null:
		push_error("GameSession: não foi possível carregar " + path)
		is_loading_level = false
		return

	current_level = packed_scene.instantiate()
	current_level.name = "ActiveLevel"
	current_level_path = path
	level_container.add_child(current_level)

	await get_tree().process_frame
	await get_tree().process_frame

	var controller := current_level.find_child("LevelController", true, false)
	var retry_panel := persistent_ui.get_node_or_null("RetryPanel")
	if is_instance_valid(retry_panel) and retry_panel.has_method("on_level_loaded"):
		retry_panel.on_level_loaded(controller)
	if persistent_ui.has_method("on_level_loaded"):
		persistent_ui.call("on_level_loaded")

	level_loaded.emit(current_level)
	is_loading_level = false
	print("GameSession: fase carregada: ", current_level_path)


func reload_current_level() -> void:
	if current_level_path.is_empty():
		return
	await load_level(current_level_path)


func get_level_number() -> int:
	var basename := current_level_path.get_file().get_basename()
	if basename.begins_with("level_"):
		return maxi(1, int(basename.trim_prefix("level_")))
	return 1
