extends Node

const GAME_SESSION_PATH := "res://Scenes/game_session.tscn"
var target_scene_path: String = ""
var initial_level_path: String = ""

func change_scene(path: String) -> void:
	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene.has_method("load_level") and path.begins_with("res://Scenes/level_"):
		current_scene.call_deferred("load_level", path)
		return
	target_scene_path = path
	get_tree().change_scene_to_file("res://Scenes/loading.tscn")


func reload_current_level() -> void:
	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene.has_method("reload_current_level"):
		current_scene.call_deferred("reload_current_level")
		return
	if not initial_level_path.is_empty():
		change_scene(initial_level_path)
