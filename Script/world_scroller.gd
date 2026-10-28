extends Node3D


@export var speed: float = 2.0
@export var tile_length: float = 20.0
@export var recycle_distance: float = -60.0


var running := true

# Posição real, com precisão total.
# Essa posição nunca recebe o snap.
var high_precision_position: Vector3


func _ready():

	high_precision_position = global_position


func _process(delta):

	if not running:
		return

	# Movimento de alta precisão.
	high_precision_position.z -= speed * delta

	# Mantém a posição real antes do snap.
	global_position = high_precision_position

	# Reciclagem dos tiles.
	for tile in get_children():

		if not tile.is_in_group("tiles"):
			continue

		if tile.global_position.z < recycle_distance:

			var farthest_z = get_farthest_tile_z()

			tile.global_position.z = farthest_z + tile_length


func get_farthest_tile_z() -> float:

	var farthest_z = -INF

	for tile in get_children():

		if not tile.is_in_group("tiles"):
			continue

		if tile.global_position.z > farthest_z:

			farthest_z = tile.global_position.z

	return farthest_z
