extends Node3D

@export_category("Movimento")
@export var icon: Texture2D
@export var disabled_icon: Texture2D
@export var speed: float = 7.0
@export var max_lifetime: float = 6.0
@export var hit_distance: float = 0.45

var target: Node3D
var shooter: Node3D
var damage: float = 8.0
var lifetime: float = 0.0
var resolved: bool = false

func setup(target_node: Node3D, shooter_node: Node3D, projectile_damage: float) -> void:
	target = target_node
	shooter = shooter_node
	damage = projectile_damage

func _ready() -> void:
	var area := get_node_or_null("Area3D") as Area3D
	if is_instance_valid(area):
		area.monitoring = false
		area.monitorable = false

func _process(delta: float) -> void:
	if resolved:
		return
	lifetime += delta
	if lifetime >= max_lifetime or not _is_target_valid():
		finish()
		return
	var target_position := target.global_position
	var magic_target := target.get_node_or_null("MagicTarget") as Node3D
	if is_instance_valid(magic_target):
		target_position = magic_target.global_position
	else:
		target_position.y += 1.0
	var offset := target_position - global_position
	var distance := offset.length()
	if distance <= hit_distance:
		apply_target_damage()
		return
	var direction := offset / distance
	var movement := direction * speed * delta
	var world_scroller := get_tree().get_first_node_in_group("world_scroller")
	if is_instance_valid(world_scroller) and world_scroller.get("running") == true:
		movement.z -= float(world_scroller.get("speed")) * delta
	if movement.length() >= distance:
		global_position = target_position
		apply_target_damage()
	else:
		global_position += movement
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)
		rotation.x += deg_to_rad(-90.0)

func _is_target_valid() -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or target.get("dead") == true:
		return false
	var current_health = target.get("health")
	return current_health == null or float(current_health) > 0.0

func apply_target_damage() -> void:
	if resolved:
		return
	if _is_target_valid() and target.has_method("take_damage"):
		target.call("take_damage", damage, "magic")
	finish()

func finish() -> void:
	if resolved:
		return
	resolved = true
	queue_free()
