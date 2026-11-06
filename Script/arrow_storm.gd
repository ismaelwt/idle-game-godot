extends Node3D

signal finished

@export_category("Skill")
@export var icon: Texture2D
@export var disabled_icon: Texture2D
@export var cooldown: float = 12.0
@export var mana_cost: float = 40.0

@export_category("Arrow Storm")
@export var damage: float = 28.0
@export var radius: float = 5.0
@export var arrow_count: int = 18
@export var fall_height: float = 6.0
@export var fall_speed: float = 4.5
@export var stagger_interval: float = 0.07

const ARROW_SCENE: PackedScene = preload("res://Scenes/arrow_projectile.tscn")

var center_target: Node3D
var shooter: Node3D
var character_stats: Node
var resolved: bool = false
var center_position: Vector3
var created_arrows: Array[Node3D] = []

@onready var aim_marker: Sprite3D = $Sprite3D


func get_description() -> String:
	return "ARROW STORM\nDMG: %.0f\nAREA: %.1f\nCOST: %.0f\nCooldown: %.1f s" % [
		damage,
		radius,
		mana_cost,
		cooldown
	]


func _ready() -> void:
	if not is_instance_valid(center_target):
		_finish()
		return

	center_position = center_target.global_position

	var world_scroller := get_tree().get_first_node_in_group("world_scroller")
	if is_instance_valid(world_scroller) and world_scroller is Node3D:
		reparent(world_scroller, true)

	global_position = center_position
	aim_marker.visible = true

	_spawn_arrow_rain()

	while _has_active_arrows():
		await get_tree().process_frame

	_finish()


func _has_active_arrows() -> bool:
	for arrow in created_arrows:
		if is_instance_valid(arrow):
			return true
	return false


func _spawn_arrow_rain() -> void:
	var valid_targets: Array[Node3D] = []

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if enemy.get("dying") == true:
			continue
		var enemy_health = enemy.get("health")
		if enemy_health == null or float(enemy_health) <= 0.0:
			continue

		var enemy_distance := Vector2(
			enemy.global_position.x - center_position.x,
			enemy.global_position.z - center_position.z
		).length()

		if enemy_distance <= radius:
			valid_targets.append(enemy)

	if valid_targets.is_empty():
		return

	var count := maxi(1, arrow_count)
	var arrow_parent: Node = get_parent()

	for i in range(count):
		var target_enemy := valid_targets[i % valid_targets.size()]
		if not is_instance_valid(target_enemy):
			continue

		var arrow := ARROW_SCENE.instantiate() as Node3D
		if arrow == null:
			continue

		var stats = character_stats
		var is_critical := false
		var final_damage := damage

		if is_instance_valid(stats):
			is_critical = stats.is_critical_hit()
			if is_critical:
				final_damage *= stats.get_critical_damage_multiplier()

		var impact_position := target_enemy.global_position
		impact_position.x += randf_range(-0.2, 0.2)
		impact_position.z += randf_range(-0.2, 0.2)

		# O eixo longitudinal da flecha é Z; rotaciona 90 graus em X
		# para deixar a ponta apontada para baixo durante a queda.
		arrow.rotation = Vector3(PI * 0.5, randf_range(0.0, TAU), 0.0)
		arrow.scale = Vector3(0.3, 0.3, 0.3)
		arrow.setup_falling(
			target_enemy,
			shooter,
			final_damage,
			is_critical,
			fall_speed,
			float(i) * stagger_interval
		)

		arrow_parent.add_child(arrow)
		arrow.global_position = impact_position + Vector3.UP * fall_height
		created_arrows.append(arrow)


func _finish() -> void:
	if resolved:
		return

	resolved = true
	for arrow in created_arrows:
		if is_instance_valid(arrow):
			arrow.finish()
	created_arrows.clear()

	finished.emit()
	queue_free()
