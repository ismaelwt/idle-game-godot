extends Control

@onready var inventory_panel: Panel = $InventoryPanel
@onready var drag_handle: Label = $InventoryPanel/VBoxContainer/Header/Title
@onready var attributes_panel: Control = get_parent().get_node("AttributesControl/PanelContainer")

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# O Control raiz fica independente do CenterContainer para permitir arraste.
	top_level = true
	size = Vector2(519.0, 350.0)
	call_deferred("_place_at_attributes_position")

	if is_instance_valid(drag_handle):
		drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
		drag_handle.gui_input.connect(_on_drag_handle_input)


func _place_at_attributes_position() -> void:
	if not is_instance_valid(attributes_panel):
		return

	# Centraliza o painel do inventário sobre a mesma área do painel de atributos.
	var attributes_rect := attributes_panel.get_global_rect()
	var panel_offset := inventory_panel.position
	var target_panel_position := attributes_rect.position + (attributes_rect.size - inventory_panel.size) * 0.5
	var target_root_position := target_panel_position - panel_offset

	# Mantém a janela inteira visível ao abrir.
	var viewport_size := get_viewport_rect().size
	var min_position := -panel_offset
	var max_position := viewport_size - inventory_panel.size - panel_offset
	target_root_position.x = clampf(target_root_position.x, min_position.x, maxf(max_position.x, min_position.x))
	target_root_position.y = clampf(target_root_position.y, min_position.y, maxf(max_position.y, min_position.y))

	global_position = target_root_position
	z_index = 10


func _on_drag_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			drag_offset = get_global_mouse_position() - global_position
			move_to_front()
			drag_handle.accept_event()
	elif event is InputEventMouseMotion and dragging:
		var new_global_position := get_global_mouse_position() - drag_offset
		var viewport_size := get_viewport_rect().size
		var panel_offset := inventory_panel.position
		var min_position := -panel_offset
		var max_position := viewport_size - inventory_panel.size - panel_offset

		new_global_position.x = clampf(new_global_position.x, min_position.x, maxf(max_position.x, min_position.x))
		new_global_position.y = clampf(new_global_position.y, min_position.y, maxf(max_position.y, min_position.y))

		global_position = new_global_position
		drag_handle.accept_event()
