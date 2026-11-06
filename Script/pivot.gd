extends Node3D

const CharacterSelectionDataScript = preload("res://Script/character_selection_data.gd")

@onready var camera: Camera3D = $Camera3D

@export var hero_z_offset: float = -6.0
@export_range(0.1, 3.0, 0.1) var camera_transition_duration: float = 1.0

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
var camera_follow_tween: Tween = null

var units_per_pixel: float = 0.0
var high_precision_position: Vector3
var snapped_world_position: Vector3

@export_category("Camera Shake")
@export var critical_shake_strength: float = 0.035
@export var critical_shake_duration: float = 0.16

var camera_shake_tween: Tween = null
var camera_base_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("camera_pivot")
	process_priority = 100
	followed_hero = _find_selected_hero()

	if not is_instance_valid(camera):
		print("ERRO: Camera3D não encontrada.")
		return

	if not is_instance_valid(world_scroller):
		print("ERRO: WorldScroller não encontrado.")
		return

	camera_base_offset = Vector2(camera.h_offset, camera.v_offset)

	if is_instance_valid(followed_hero):
		camera.global_position.z = followed_hero.global_position.z + hero_z_offset

	print("=== PIXEL PERFECT ===")
	print("Camera: ", camera.name)
	print("WorldScroller: ", world_scroller.name)

	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		print("Camera Orthographic Size: ", camera.size)
	else:
		print("AVISO: Camera não está Orthographic.")


func _process(_delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(world_scroller):
		return

	# Detecta a morte do herói acompanhado e troca o foco suavemente.
	if not _is_hero_alive(followed_hero):
		var next_hero := _find_selected_hero()
		if is_instance_valid(next_hero) and next_hero != followed_hero:
			_change_followed_hero(next_hero)

	if not is_instance_valid(followed_hero):
		return

	# Durante a transição, o Tween controla a posição Z da câmera.
	# Depois dela, o acompanhamento volta a ser direto.
	if camera_follow_tween == null or not camera_follow_tween.is_running():
		camera.global_position.z = followed_hero.global_position.z + hero_z_offset

	if not pixel_snap_enabled:
		return

	var viewport_size := sub_viewport.get_visible_rect().size
	if viewport_size.y <= 0.0:
		return

	# Unidades de mundo por pixel.
	units_per_pixel = camera.size / viewport_size.y

	# Posição real do WorldScroller.
	high_precision_position = world_scroller.high_precision_position

	# World -> Camera Space.
	var world_to_camera := camera.global_transform.affine_inverse()
	var camera_to_world := camera.global_transform
	var camera_space := world_to_camera * high_precision_position

	# Snap X.
	camera_space.x = round(camera_space.x / units_per_pixel) * units_per_pixel

	# Snap Y.
	camera_space.y = round(camera_space.y / units_per_pixel) * units_per_pixel

	# Camera Space -> World.
	snapped_world_position = camera_to_world * camera_space

	# Aplica ao WorldScroller.
	world_scroller.global_position = snapped_world_position


func _change_followed_hero(next_hero: Node3D) -> void:
	if not is_instance_valid(next_hero):
		return

	followed_hero = next_hero

	if camera_follow_tween != null and camera_follow_tween.is_running():
		camera_follow_tween.kill()

	var target_z := followed_hero.global_position.z + hero_z_offset
	camera_follow_tween = create_tween()
	camera_follow_tween.set_trans(Tween.TRANS_SINE)
	camera_follow_tween.set_ease(Tween.EASE_IN_OUT)
	camera_follow_tween.tween_property(
		camera,
		"global_position:z",
		target_z,
		camera_transition_duration
	)

	print("=== CÂMERA: NOVO HERÓI EM FOCO: ", followed_hero.name, " ===")


func _find_selected_hero() -> Node3D:
	var manager := get_tree().get_first_node_in_group("party_manager") as PartyManager
	if is_instance_valid(manager):
		var reference_hero := manager.get_alive_reference_hero()
		if is_instance_valid(reference_hero):
			return reference_hero

	var selected_id := CharacterSelectionData.get_selected_character_id()
	var candidates := get_tree().get_nodes_in_group("party_heroes")

	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		for candidate in parent_node.get_children():
			if candidate is Node3D and not candidates.has(candidate):
				candidates.append(candidate)

	for candidate in candidates:
		if not candidate is Node3D or not _is_hero_alive(candidate):
			continue

		var stats = candidate.get("character_stats")
		if not is_instance_valid(stats):
			stats = candidate.get_node_or_null("CharacterStats")
		if not is_instance_valid(stats):
			stats = candidate.find_child("CharacterStats", true, false)

		if is_instance_valid(stats):
			var hero_id := CharacterSelectionDataScript.normalize_hero_id(
				str(stats.get("hero_id"))
			)
			if hero_id == selected_id:
				return candidate

	# O herói selecionado morreu; segue qualquer outro herói vivo.
	for candidate in candidates:
		if candidate is Node3D and _is_hero_alive(candidate):
			var stats = candidate.get("character_stats")
			if not is_instance_valid(stats):
				stats = candidate.get_node_or_null("CharacterStats")
			if not is_instance_valid(stats):
				stats = candidate.find_child("CharacterStats", true, false)
			if is_instance_valid(stats):
				return candidate

	return null


func _is_hero_alive(hero: Variant) -> bool:
	if not is_instance_valid(hero) or not hero is Node3D or not _has_property(hero, "dead"):
		return false

	return not bool(hero.get("dead"))


func _has_property(object: Object, property_name: String) -> bool:
	if not is_instance_valid(object):
		return false

	for property_info in object.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true

	return false


func shake_camera() -> void:
	if not is_instance_valid(camera):
		return

	if camera_shake_tween != null and camera_shake_tween.is_running():
		camera_shake_tween.kill()

	_set_camera_shake_offset(Vector2.ZERO)

	var strength := maxf(critical_shake_strength, 0.0)
	var step_duration := maxf(critical_shake_duration, 0.04) / 5.0
	var offsets: Array[Vector2] = [
		Vector2(strength, -strength * 0.5),
		Vector2(-strength, strength * 0.5),
		Vector2(strength * 0.5, strength),
		Vector2(-strength * 0.5, -strength),
		Vector2.ZERO
	]

	camera_shake_tween = create_tween()
	var previous_offset := Vector2.ZERO
	for offset in offsets:
		camera_shake_tween.tween_method(
			_set_camera_shake_offset,
			previous_offset,
			offset,
			step_duration
		)
		previous_offset = offset


func _set_camera_shake_offset(offset: Vector2) -> void:
	if not is_instance_valid(camera):
		return

	camera.h_offset = camera_base_offset.x + offset.x
	camera.v_offset = camera_base_offset.y + offset.y
