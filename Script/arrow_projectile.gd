extends Node3D

signal finished
signal visual_impact_reached

@export_category("Movimento")
@export var speed: float = 18.0
@export var max_lifetime: float = 5.0

@export_category("Dano")
@export var damage: float = 10.0
@export var applies_burning: bool = false

const BURNING_STATUS_SCENE: PackedScene = preload("res://Scenes/burning_status.tscn")

var target: Node3D = null
var target_position_snapshot: Vector3 = Vector3.ZERO
var has_target_position_snapshot: bool = false
var shooter: Node3D = null
var lifetime: float = 0.0
var resolved: bool = false
var is_critical: bool = false

var falling_mode: bool = false
var fall_speed: float = 4.5
var fall_delay: float = 0.0
var fall_started: bool = false
var visual_only: bool = false
var has_visual_landing_position: bool = false
var visual_landing_position: Vector3 = Vector3.ZERO

@onready var area: Area3D = $Arrow/Area3D


func _ready() -> void:
	if visual_only:
		area.monitoring = false
		area.monitorable = false

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)


func setup(
	target_node: Node3D,
	shooter_node: Node3D,
	projectile_damage: float,
	critical_hit: bool = false
) -> void:
	target = target_node
	if is_instance_valid(target_node):
		target_position_snapshot = target_node.global_position
		has_target_position_snapshot = true
	shooter = shooter_node
	damage = projectile_damage
	is_critical = critical_hit


func setup_falling(
	target_node: Node3D,
	shooter_node: Node3D,
	projectile_damage: float,
	critical_hit: bool,
	projectile_fall_speed: float,
	delay: float
) -> void:
	setup(target_node, shooter_node, projectile_damage, critical_hit)
	falling_mode = true
	fall_speed = maxf(projectile_fall_speed, 0.01)
	fall_delay = maxf(delay, 0.0)


func setup_visual_falling(
	target_node: Node3D,
	projectile_fall_speed: float,
	delay: float
) -> void:
	target = target_node
	if is_instance_valid(target_node):
		target_position_snapshot = target_node.global_position
		has_target_position_snapshot = true
	falling_mode = true
	visual_only = true
	fall_speed = maxf(projectile_fall_speed, 0.01)
	fall_delay = maxf(delay, 0.0)
	if is_instance_valid(area):
		area.monitoring = false
		area.monitorable = false


func _process(delta: float) -> void:
	if resolved:
		return

	lifetime += delta
	if lifetime >= max_lifetime:
		finish()
		return

	if not is_instance_valid(target) and not has_target_position_snapshot and not has_visual_landing_position:
		finish()
		return

	# Se o alvo morreu, o projétil ainda completa seu percurso visual
	# até a última posição conhecida, mas apply_target_damage não causa dano.
	if falling_mode:
		_process_falling(delta)
		return

	_process_direct_projectile(delta)


func setup_visual_falling_at_position(
	target_node: Node3D,
	landing_position: Vector3,
	projectile_fall_speed: float,
	delay: float
) -> void:
	target = target_node
	if is_instance_valid(target_node):
		target_position_snapshot = target_node.global_position
		has_target_position_snapshot = true
	falling_mode = true
	visual_only = true
	has_visual_landing_position = true
	visual_landing_position = landing_position
	fall_speed = maxf(projectile_fall_speed, 0.01)
	fall_delay = maxf(delay, 0.0)
	if is_instance_valid(area):
		area.monitoring = false
		area.monitorable = false


func _process_falling(delta: float) -> void:
	if fall_delay > 0.0:
		fall_delay = maxf(fall_delay - delta, 0.0)
		return

	fall_started = true
	var target_position := _get_target_position()
	if visual_only and has_visual_landing_position:
		target_position.x = visual_landing_position.x
		target_position.z = visual_landing_position.z
	# Mantém a flecha alinhada horizontalmente ao alvo enquanto cai,
	# inclusive quando o WorldScroller desloca o cenário.
	global_position.x = target_position.x
	global_position.z = target_position.z
	var movement := fall_speed * delta

	if absf(global_position.y - target_position.y) <= movement:
		global_position.y = target_position.y
		if visual_only:
			visual_impact_reached.emit()
			finish()
		else:
			apply_target_damage()
	else:
		global_position.y = move_toward(
			global_position.y,
			target_position.y,
			movement
		)


func _get_target_position() -> Vector3:
	var target_is_alive: bool = (
		is_instance_valid(target)
		and target.get("dead") != true
		and target.get("dying") != true
		and (target.get("health") == null or float(target.get("health")) > 0.0)
	)
	if not target_is_alive:
		if visual_only and has_visual_landing_position:
			return visual_landing_position
		return target_position_snapshot

	var target_position: Vector3 = target.global_position
	var magic_target: Node3D = target.get_node_or_null("MagicTarget")

	if is_instance_valid(magic_target):
		target_position = magic_target.global_position
	else:
		target_position.y += 1.0

	return target_position


func _process_direct_projectile(delta: float) -> void:
	var target_position := _get_target_position()
	var to_target: Vector3 = target_position - global_position
	var distance: float = to_target.length()

	if distance <= 0.001:
		apply_target_damage()
		return

	var direction: Vector3 = to_target / distance
	var movement: Vector3 = direction * speed * delta
	var world_scroller = get_tree().get_first_node_in_group("world_scroller")

	if is_instance_valid(world_scroller) and world_scroller.running:
		movement.z -= world_scroller.speed * delta

	if movement.length() >= distance:
		global_position = target_position
		apply_target_damage()
	else:
		global_position += movement


func _on_body_entered(body: Node3D) -> void:
	if resolved or visual_only:
		return

	if is_instance_valid(shooter):
		if body == shooter or shooter.is_ancestor_of(body):
			return

	if not is_instance_valid(target):
		finish()
		return

	var node: Node = body
	while node != null:
		if node == target:
			if target.get("dead") != true and target.get("dying") != true:
				apply_target_damage()
			else:
				finish()
			return
		node = node.get_parent()


func apply_target_damage() -> void:
	if resolved:
		return

	if not is_instance_valid(target):
		finish()
		return

	if (
		target.get("dead") == true
		or target.get("dying") == true
		or (target.get("health") != null and float(target.get("health")) <= 0.0)
	):
		finish()
		return

	if target.has_method("take_damage"):
		var shooter_stats = shooter.get_node_or_null("CharacterStats") if is_instance_valid(shooter) else null
		if is_instance_valid(shooter_stats):
			var target_health := maxf(float(target.get("health")), 0.0)
			shooter_stats.apply_on_hit_effects(minf(damage, target_health))
			target.call("take_damage", damage, is_critical)
			if is_critical:
				var camera_pivot := get_tree().get_first_node_in_group("camera_pivot")
				if is_instance_valid(camera_pivot):
					camera_pivot.shake_camera()
		else:
			target.call("take_damage", damage, "physical")

		if applies_burning and _is_target_alive(target) and randf() < 0.20:
			_apply_burning(target)

	finish()


func _is_target_alive(target_node: Node) -> bool:
	if not is_instance_valid(target_node):
		return false
	if target_node.get("dying") == true:
		return false
	var target_health = target_node.get("health")
	return target_health == null or float(target_health) > 0.0


func _apply_burning(target_node: Node) -> void:
	var existing_status := target_node.get_node_or_null("BurningStatus")
	if is_instance_valid(existing_status):
		if existing_status.has_method("refresh"):
			existing_status.call("refresh")
		return

	var burning_status := BURNING_STATUS_SCENE.instantiate()
	burning_status.name = "BurningStatus"
	target_node.add_child(burning_status)


func finish() -> void:
	if resolved:
		return

	resolved = true
	finished.emit()
	queue_free()
