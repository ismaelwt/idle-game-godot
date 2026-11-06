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
@export var fall_height: float = 12.0
@export var fall_duration: float = 0.45
@export var strike_duration: float = 1.6

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
	center_position.y = get_ground_height(center_position)

	var world_scroller := get_tree().get_first_node_in_group("world_scroller")
	if is_instance_valid(world_scroller) and world_scroller is Node3D:
		reparent(world_scroller, true)

	global_position = center_position
	aim_marker.visible = true

	_apply_area_damage()
	_spawn_arrow_rain()

	await get_tree().create_timer(strike_duration).timeout
	_finish()


func get_ground_height(position: Vector3) -> float:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 8.0,
		position + Vector3.DOWN * 20.0
	)
	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		return float(hit.position.y)
	return position.y


func _apply_area_damage() -> void:
	if resolved:
		return

	var critical_chance := 0.0
	var critical_multiplier := 1.5
	var damage_multiplier := 1.0

	if is_instance_valid(character_stats):
		critical_chance = character_stats.get_critical_chance()
		critical_multiplier = character_stats.get_critical_damage_multiplier()

	var is_critical := randf() * 100.0 < critical_chance
	var final_damage := damage
	if is_critical:
		final_damage *= critical_multiplier

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if not enemy.has_method("take_damage"):
			continue
		if enemy.get("dying") == true:
			continue

		var health_value = enemy.get("health")
		if health_value == null or float(health_value) <= 0.0:
			continue

		var enemy_position: Vector3 = enemy.global_position
		var distance := Vector2(
			enemy_position.x - center_position.x,
			enemy_position.z - center_position.z
		).length()

		if distance > radius:
			continue

		var actual_damage := minf(final_damage, float(health_value))
		enemy.call("take_damage", final_damage, is_critical)

		if is_instance_valid(character_stats):
			character_stats.apply_on_hit_effects(actual_damage)

	if is_critical:
		var camera_pivot := get_tree().get_first_node_in_group("camera_pivot")
		if is_instance_valid(camera_pivot):
			camera_pivot.shake_camera()


func _spawn_arrow_rain() -> void:
	var count := maxi(1, arrow_count)

	for i in range(count):
		var angle := randf_range(0.0, TAU)
		var distance := sqrt(randf()) * radius
		var impact_position := center_position + Vector3(
			cos(angle) * distance,
			0.0,
			sin(angle) * distance
		)

		var arrow := ARROW_SCENE.instantiate() as Node3D
		if arrow == null:
			continue

		var area := arrow.get_node_or_null("Arrow/Area3D") as Area3D
		if is_instance_valid(area):
			area.monitoring = false
			area.monitorable = false

		# O projétil é apenas visual nesta skill; o dano em área é aplicado uma vez.
		if "resolved" in arrow:
			arrow.set("resolved", true)
		arrow.set_process(false)
		arrow.set_physics_process(false)

		var arrow_scroller := get_parent()
		arrow_scroller.add_child(arrow)
		arrow.global_position = impact_position + Vector3.UP * fall_height
		arrow.scale = Vector3(0.3, 0.3, 0.3)
		created_arrows.append(arrow)

		var tween := arrow.create_tween()
		tween.tween_property(
			arrow,
			"global_position",
			impact_position + Vector3.UP * 0.15,
			fall_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(arrow.queue_free)


func _finish() -> void:
	if resolved:
		return
	resolved = true

	for arrow in created_arrows:
		if is_instance_valid(arrow):
			arrow.queue_free()
	created_arrows.clear()

	finished.emit()
	queue_free()
