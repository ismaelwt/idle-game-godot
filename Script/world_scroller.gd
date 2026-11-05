extends Node3D


@export var speed: float = 2.0
@export var tile_length: float = 20.0
@export var recycle_distance: float = -60.0

# Com tile_length = 20, o valor 0.75 mantém um tile visível
# na maior parte do percurso e dois durante a transição.
@export_range(0.5, 1.0, 0.05) var visibility_distance_multiplier: float = 0.75


var running := true

# Posição real, com precisão total.
# Essa posição nunca recebe o snap.
var high_precision_position: Vector3


func _ready() -> void:
	high_precision_position = global_position


func _process(delta: float) -> void:
	if running:
		# Movimento de alta precisão.
		high_precision_position.z -= speed * delta

		# Mantém a posição real antes do snap.
		global_position = high_precision_position

		# Reciclagem dos tiles.
		for tile in get_children():
			if not tile.is_in_group("tiles"):
				continue

			if tile.global_position.z < recycle_distance:
				var farthest_z := get_farthest_tile_z()
				tile.global_position.z = farthest_z + tile_length

	# Atualiza a visibilidade mesmo quando o cenário está parado.
	_update_tile_visibility()


func _update_tile_visibility() -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return

	var visibility_distance := tile_length * visibility_distance_multiplier

	for tile in get_children():
		if not tile.is_in_group("tiles"):
			continue

		# O cenário percorre o eixo Z; usamos a distância nesse eixo
		# para ativar o próximo tile antes da transição e ocultar o anterior
		# depois que ele se afasta da câmera.
		var distance_z := absf(tile.global_position.z - camera.global_position.z)
		tile.visible = distance_z <= visibility_distance


func get_farthest_tile_z() -> float:
	var farthest_z := -INF

	for tile in get_children():
		if not tile.is_in_group("tiles"):
			continue

		if tile.global_position.z > farthest_z:
			farthest_z = tile.global_position.z

	return farthest_z
