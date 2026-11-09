extends Control

@onready var inventory_panel: Panel = $InventoryPanel
@onready var drag_handle: Label = $InventoryPanel/VBoxContainer/Header/Title

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	if is_instance_valid(drag_handle):
		drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
		drag_handle.gui_input.connect(_on_drag_handle_input)


func _on_drag_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			drag_offset = get_global_mouse_position() - inventory_panel.global_position
			move_to_front()
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		var new_global_position := get_global_mouse_position() - drag_offset
		var viewport_size := get_viewport_rect().size
		var max_position := viewport_size - inventory_panel.size
		new_global_position.x = clampf(new_global_position.x, 0.0, maxf(max_position.x, 0.0))
		new_global_position.y = clampf(new_global_position.y, 0.0, maxf(max_position.y, 0.0))
		inventory_panel.global_position = new_global_position
		accept_event()
