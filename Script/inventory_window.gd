extends Control

@onready var inventory_panel: Panel = $InventoryPanel
@onready var attributes_panel: Control = get_parent().get_node("AttributesControl/PanelContainer")

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# O Control raiz é a área de arraste. O Panel interno mantém seus próprios botões.
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	call_deferred("_place_at_attributes_position")


func _place_at_attributes_position() -> void:
	if not is_instance_valid(attributes_panel):
		return

	var attributes_rect := attributes_panel.get_global_rect()
	var panel_offset := inventory_panel.position
	var target_panel_position := attributes_rect.position + (attributes_rect.size - inventory_panel.size) * 0.5
	var target_root_position := target_panel_position - panel_offset

	var viewport_size := get_viewport_rect().size
	var min_position := -panel_offset
	var max_position := viewport_size - inventory_panel.size - panel_offset
	target_root_position.x = clampf(target_root_position.x, min_position.x, maxf(max_position.x, min_position.x))
	target_root_position.y = clampf(target_root_position.y, min_position.y, maxf(max_position.y, min_position.y))

	global_position = target_root_position
	z_index = 10


# O clique é recebido pelo Control maior, nas áreas que não são cobertas pelo Panel.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		drag_offset = get_global_mouse_position() - global_position
		move_to_front()
		accept_event()


func _input(event: InputEvent) -> void:
	if not dragging:
		return

	if event is InputEventMouseMotion:
		var new_global_position := get_global_mouse_position() - drag_offset
		var viewport_size := get_viewport_rect().size
		var panel_offset := inventory_panel.position
		var min_position := -panel_offset
		var max_position := viewport_size - inventory_panel.size - panel_offset

		new_global_position.x = clampf(new_global_position.x, min_position.x, maxf(max_position.x, min_position.x))
		new_global_position.y = clampf(new_global_position.y, min_position.y, maxf(max_position.y, min_position.y))
		global_position = new_global_position
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		get_viewport().set_input_as_handled()
