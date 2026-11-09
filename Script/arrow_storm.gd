extends Node3D

signal finished

@export_category("Skill")
@export var icon: Texture2D
@export var disabled_icon: Texture2D
@export var cooldown: float = 12.0
@export var mana_cost: float = 40.0

@export_category("Arrow Storm")
@export var damage: float = 28.0
@export var radius: float = 12.0
@export var arrow_count: int = 5
@export_range(0.1, 1.0, 0.05) var arrow_spread_factor: float = 0.65
@export var fall_height: float = 9.0
@export var fall_speed: float = 8.0
@export var stagger_interval: float = 0.2

const ARROW_SCENE: PackedScene = preload("res://Scenes/arrow_projectile.tscn")
const FIRE_ARROW_SCENE: PackedScene = preload("res://Scenes/fire_arrow_projectile.tscn")
const BURNING_STATUS_SCENE: PackedScene = preload("res://Scenes/burning_status.tscn")

var center_target: Node3D
var shooter: Node3D
var character_stats: Node
var resolved: bool = false
var center_position: Vector3
var has_center_position: bool = false
var created_arrows: Array[Node3D] = []
var area_damage_applied: bool = false

@onready var aim_marker: Sprite3D = $Sprite3D


func get_description() -> String:
	return "ARROW STORM\nDMG: %.0f\nAREA: %.1f\nCOST: %.0f\nCooldown: %.1f s" % [
		damage,
		radius,
		mana_cost,
		cooldown
	]


func _ready() -> void:
	if not has_center_position:
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
		aim_marker.visible = false
		return

	# O marcador visual acompanha todos os inimigos dentro do raio.
	aim_marker.visible = false
	for target_enemy in valid_targets:
		if not is_instance_valid(target_enemy):
			continue
		var target_marker := aim_marker.duplicate() as Sprite3D
		if target_marker == null:
			continue
		add_child(target_marker)
		target_marker.visible = true
		target_marker.global_position = target_enemy.global_position + Vector3.UP * 0.03
		_animate_target_marker(target_marker)

	# A quantidade de flechas é exclusivamente visual.
	var count := maxi(1, arrow_count)
	var arrow_parent: Node = get_parent()

	for i in range(count):
		var target_enemy := valid_targets[i % valid_targets.size()]
		if not is_instance_valid(target_enemy):
			continue

		var use_fire_arrow: bool = (
			is_instance_valid(character_stats)
			and bool(character_stats.call("has_skill", "fire_arrow"))
		)
		var arrow_scene: PackedScene = FIRE_ARROW_SCENE if use_fire_arrow else ARROW_SCENE
		var arrow := arrow_scene.instantiate() as Node3D
		if arrow == null:
			continue

		# Distribui os impactos visualmente por toda a área circular.
		var angle := randf_range(0.0, TAU)
		var distance := sqrt(randf()) * radius * arrow_spread_factor
		var landing_position := center_position + Vector3(
			cos(angle) * distance,
			0.0,
			sin(angle) * distance
		)
		var target_height_position := target_enemy.global_position
		var magic_target := target_enemy.get_node_or_null("MagicTarget")
		if is_instance_valid(magic_target):
			target_height_position.y = magic_target.global_position.y
		else:
			target_height_position.y += 1.0
		landing_position.y = target_height_position.y

		arrow.rotation = Vector3(PI * 0.5, randf_range(0.0, TAU), 0.0)
		arrow.scale = Vector3(0.3, 0.3, 0.3)
		arrow.setup_visual_falling_at_position(
			target_enemy,
			landing_position,
			fall_speed,
			float(i) * stagger_interval
		)
		arrow.visual_impact_reached.connect(_on_visual_arrow_impact)

		arrow_parent.add_child(arrow)
		arrow.global_position = landing_position + Vector3.UP * fall_height
		created_arrows.append(arrow)


func _animate_target_marker(marker: Sprite3D) -> void:
	if not is_instance_valid(marker):
		return

	# Pisca três vezes e depois desaparece suavemente.
	var tween := marker.create_tween()
	for i in range(3):
		tween.tween_property(marker, "modulate:a", 0.0, 0.10)
		tween.tween_property(marker, "modulate:a", 1.0, 0.10)

	tween.tween_property(marker, "modulate:a", 0.0, 0.35)
	tween.tween_callback(marker.queue_free)


func _on_visual_arrow_impact() -> void:
	if area_damage_applied:
		return

	area_damage_applied = true
	_apply_area_damage()


func _apply_area_damage() -> void:
	var critical_chance := 0.0
	var critical_multiplier := 1.5
	if is_instance_valid(character_stats):
		critical_chance = character_stats.get_critical_chance()
		critical_multiplier = character_stats.get_critical_damage_multiplier()

	var is_critical := randf() * 100.0 < critical_chance
	var final_damage := damage
	if is_critical:
		final_damage *= critical_multiplier

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if not enemy.has_method("take_damage"):
			continue
		if enemy.get("dying") == true:
			continue
		var enemy_health = enemy.get("health")
		if enemy_health == null or float(enemy_health) <= 0.0:
			continue

		var distance := Vector2(
			enemy.global_position.x - center_position.x,
			enemy.global_position.z - center_position.z
		).length()
		if distance > radius:
			continue

		var actual_damage := minf(final_damage, float(enemy_health))
		enemy.call("take_damage", final_damage, is_critical)
		if is_instance_valid(character_stats):
			character_stats.apply_on_hit_effects(actual_damage)
			if (
				character_stats.has_skill("fire_arrow")
				and enemy.get("dying") != true
				and float(enemy.get("health")) > 0.0
				and randf() < 0.20
			):
				_apply_burning(enemy)

	if is_critical:
		var camera_pivot := get_tree().get_first_node_in_group("camera_pivot")
		if is_instance_valid(camera_pivot):
			camera_pivot.shake_camera()

func _apply_burning(target: Node) -> void:
	var existing_status := target.get_node_or_null("BurningStatus")
	if is_instance_valid(existing_status):
		if existing_status.has_method("refresh"):
			existing_status.call("refresh")
		return

	var burning_status := BURNING_STATUS_SCENE.instantiate()
	burning_status.name = "BurningStatus"
	target.add_child(burning_status)


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
