class_name MapWindow
extends Control

# Janela que mostra uma parte de uma imagem grande e permite arrastar.
# Sem zoom e sem escala: 1 pixel da imagem = 1 pixel da tela.

@export var allow_drag: bool = true
@export var scroll_time: float = 0.35

@onready var content: Control = $Content
@onready var phase_pointer: AnimatedSprite2D = $Content/Markers/Pointer/AnimatedSprite2D

const DRAG_THRESHOLD := 6.0

# Vira true quando um arrasto termina. A cena usa isso para não abrir
# uma fase sem querer ao soltar o mouse em cima de um botão.
var just_dragged: bool = false

var _pressing: bool = false
var _dragging: bool = false
var _drag_distance: float = 0.0
var _tween: Tween


func _ready() -> void:
	print("janela=", size, "  content=", content.size, "  pos=", content.position)
	phase_pointer.play("rotate")
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# O Content assume o tamanho da imagem (726x732).
	var map_rect := content.get_node_or_null("Map") as TextureRect

	if map_rect != null and map_rect.texture != null:
		var img_size := map_rect.texture.get_size()
		map_rect.position = Vector2.ZERO
		map_rect.size = img_size
		content.size = img_size

	content.position = _clamp_position(content.position)
	resized.connect(_on_resized)


# Mantém a imagem cobrindo a janela: nunca aparece área vazia.
func _clamp_position(pos: Vector2) -> Vector2:
	var slack := size - content.size
	var result := pos

	if slack.x >= 0.0:
		result.x = slack.x * 0.5
	else:
		result.x = clampf(pos.x, slack.x, 0.0)

	if slack.y >= 0.0:
		result.y = slack.y * 0.5
	else:
		result.y = clampf(pos.y, slack.y, 0.0)

	return result.round()


func _input(event: InputEvent) -> void:
	if not allow_drag or not is_visible_in_tree():
		return

	var button := event as InputEventMouseButton

	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			if get_global_rect().has_point(get_global_mouse_position()):
				_pressing = true
				_dragging = false
				_drag_distance = 0.0
		else:
			if _dragging:
				just_dragged = true
				_clear_just_dragged.call_deferred()

			_pressing = false
			_dragging = false

		return

	var motion := event as InputEventMouseMotion

	if motion == null or not _pressing:
		return

	_drag_distance += motion.relative.length()

	# Só começa a arrastar depois de mover alguns pixels, assim um clique
	# normal num botão continua funcionando.
	if _drag_distance >= DRAG_THRESHOLD:
		_dragging = true

	if _dragging:
		_kill_tween()
		content.position = _clamp_position(content.position + motion.relative)


func _clear_just_dragged() -> void:
	just_dragged = false


# Leva a janela até um ponto da IMAGEM, deixando-o no centro.
func scroll_to_point(point: Vector2, animated: bool = true) -> void:
	var target := _clamp_position(size * 0.5 - point)

	_kill_tween()

	if not animated or scroll_time <= 0.0:
		content.position = target
		return

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(content, "position", target, scroll_time)


# Atalho: centraliza num marcador (ex.: Fase3).
func scroll_to_marker(marker: Control, animated: bool = true) -> void:
	scroll_to_point(marker.position + marker.size * 0.5, animated)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _on_resized() -> void:
	content.position = _clamp_position(content.position)
