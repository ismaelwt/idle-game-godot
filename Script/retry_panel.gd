extends Panel

var level_controller: Node = null

@onready var restart_button = $CenterContainer/PanelContainer/VBoxContainer/Retry
@onready var map_button = $CenterContainer/PanelContainer/VBoxContainer/Map

@onready var enable_auto_retry_button = $CenterContainer/PanelContainer/Control/EnableAutoRetryButton
@onready var disable_auto_retry_button = $CenterContainer/PanelContainer/Control/DisableAutoRetryButton

@onready var close_button = $CenterContainer/PanelContainer/Background/TextureRect/CloseButton
@onready var title_label = $CenterContainer/PanelContainer/VBoxContainer/Title


func _ready():
	visible = false

	restart_button.pressed.connect(_on_restart_pressed)
	map_button.pressed.connect(_on_map_pressed)

	enable_auto_retry_button.pressed.connect(_on_enable_auto_retry_pressed)
	disable_auto_retry_button.pressed.connect(_on_disable_auto_retry_pressed)
	close_button.pressed.connect(_on_close_pressed)

	var auto_retry_enabled = SaveManager.load_auto_retry()
	level_controller = _find_level_controller()
	if is_instance_valid(level_controller):
		level_controller.automatic_retry = auto_retry_enabled
	map_button.hide()
	update_auto_retry_buttons()


func _process(_delta):
	if not is_instance_valid(level_controller):
		level_controller = _find_level_controller()
	if not is_instance_valid(level_controller):
		return

	if SaveManager.automatic_retry:
		return

	if level_controller.state == level_controller.State.DEFEAT:
		title_label.text = "DEFEAT"
		visible = true

	elif level_controller.state == level_controller.State.VICTORY:
		title_label.text = "VICTORY"
		visible = true


func update_auto_retry_buttons():
	enable_auto_retry_button.visible = SaveManager.automatic_retry
	disable_auto_retry_button.visible = not SaveManager.automatic_retry


func _on_enable_auto_retry_pressed():
	SaveManager.save_auto_retry(false)
	if is_instance_valid(level_controller):
		level_controller.automatic_retry = false
	update_auto_retry_buttons()


func _on_disable_auto_retry_pressed():
	SaveManager.save_auto_retry(true)
	if is_instance_valid(level_controller):
		level_controller.automatic_retry = true
	update_auto_retry_buttons()


func _on_restart_pressed():
	Log.d("=== REINICIANDO SOMENTE A FASE ===")
	SceneLoader.reload_current_level()
	hide()


func _on_map_pressed():
	hide()


func _find_level_controller() -> Node:
	return get_tree().get_first_node_in_group("level_controller")


func on_level_loaded(controller: Node) -> void:
	level_controller = controller
	visible = false
	if is_instance_valid(level_controller):
		level_controller.automatic_retry = SaveManager.automatic_retry


func _on_close_pressed():
	hide()
