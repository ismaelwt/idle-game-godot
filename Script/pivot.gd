extends Node3D

@onready var camera: Camera3D = $Camera3D

@export var hero_z_offset: float = -6.0

@onready var sub_viewport: SubViewport = (
	get_parent()
	.get_parent()
	.get_node("SubViewport")
)

@onready var world_scroller = (
	get_parent()
	.get_node("World/WorldScroller")
)


@export var pixel_snap_enabled: bool = true


var followed_hero: Node3D = null



var units_per_pixel: float = 0.0

var high_precision_position: Vector3
var snapped_world_position: Vector3


func _ready():

	process_priority = 100
	followed_hero = _find_selected_hero()

	if not is_instance_valid(camera):

		print("ERRO: Camera3D não encontrada.")
		return

	if not is_instance_valid(world_scroller):

		print("ERRO: WorldScroller não encontrado.")
		return

	print("=== PIXEL PERFECT ===")
	print("Camera: ", camera.name)
	print("WorldScroller: ", world_scroller.name)

	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:

		print(
			"Camera Orthographic Size: ",
			camera.size
		)

	else:

		print(
			"AVISO: Camera não está Orthographic."
		)


func _process(_delta):

	if not pixel_snap_enabled:
		return

	if not is_instance_valid(camera):
		return

	if not is_instance_valid(world_scroller):
		return

	if not is_instance_valid(followed_hero):
		followed_hero = _find_selected_hero()
	if not is_instance_valid(followed_hero):
		return

	var viewport_size = (
		sub_viewport
		.get_visible_rect()
		.size
	)

	if viewport_size.y <= 0.0:
		return


	# ==========================================
	# UNIDADES DE MUNDO POR PIXEL
	# ==========================================

	units_per_pixel = (
		camera.size
		/ viewport_size.y
	)


	# ==========================================
	# POSIÇÃO REAL
	# ==========================================

	high_precision_position = (
		world_scroller.high_precision_position
	)


	# ==========================================
	# WORLD -> CAMERA SPACE
	# ==========================================

	var world_to_camera = (
		camera.global_transform.affine_inverse()
	)

	var camera_to_world = (
		camera.global_transform
	)

	var camera_space = (
		world_to_camera
		* high_precision_position
	)


	# ==========================================
	# SNAP X
	# ==========================================

	camera_space.x = (
		round(
			camera_space.x
			/ units_per_pixel
		)
		* units_per_pixel
	)


	# ==========================================
	# SNAP Y
	# ==========================================

	camera_space.y = (
		round(
			camera_space.y
			/ units_per_pixel
		)
		* units_per_pixel
	)


	# ==========================================
	# CAMERA SPACE -> WORLD
	# ==========================================

	snapped_world_position = (
		camera_to_world
		* camera_space
	)


	# ==========================================
	# APLICA AO WORLD SCROLLER
	# ==========================================

	world_scroller.global_position = (
		snapped_world_position
	)
	
	camera.global_position.z = followed_hero.global_position.z + hero_z_offset


func _find_selected_hero() -> Node3D:
	var selected_id := CharacterSelectionData.get_selected_character_id()
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		for candidate in parent_node.get_children():
			if not candidate is Node3D:
				continue
			var stats = candidate.get("character_stats")
			if not is_instance_valid(stats):
				stats = candidate.get_node_or_null("CharacterStats")
			if is_instance_valid(stats):
				if CharacterSelectionData.normalize_hero_id(str(stats.get("hero_id"))) == selected_id:
					return candidate
	var manager := get_tree().get_first_node_in_group("party_manager") as PartyManager
	if is_instance_valid(manager):
		return manager.get_main_hero()
	return null
