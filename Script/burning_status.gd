extends Node3D

@export var damage_per_tick: float = 3.0
@export var tick_interval: float = 1.0
@export var duration: float = 3.0

var remaining_duration: float = 3.0
var tick_timer: float = 1.0
var target: Node = null


func _ready() -> void:
	target = get_parent()
	remaining_duration = duration
	tick_timer = tick_interval


func refresh() -> void:
	remaining_duration = duration


func _process(delta: float) -> void:
	if not _is_target_alive():
		queue_free()
		return

	remaining_duration = maxf(remaining_duration - delta, 0.0)
	tick_timer -= delta

	if tick_timer <= 0.0:
		tick_timer += tick_interval
		_apply_burn_damage()

	if remaining_duration <= 0.0:
		queue_free()


func _is_target_alive() -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if target.get("dying") == true:
		return false

	var target_health = target.get("health")
	return target_health != null and float(target_health) > 0.0


func _apply_burn_damage() -> void:
	if not _is_target_alive():
		return
	if target.has_method("take_damage"):
		target.call("take_damage", damage_per_tick, false)
