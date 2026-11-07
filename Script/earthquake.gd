extends Node3D

signal finished

@export_category("Skill")
@export var icon: Texture2D
@export var disabled_icon: Texture2D
@export var cooldown: float = 15.0
@export var mana_cost: float = 35.0

@export_category("Earthquake")
@export var damage: int = 45
@export_range(0.0, 1.0, 0.05) var damage_animation_ratio: float = 0.45

var character_stats: Node
var resolved: bool = false
var hit_enemies: Dictionary = {}

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_area: Area3D = $Area3D


func get_description() -> String:
	return "EARTHQUAKE\nDMG: %d + bônus físico\nAREA: linear\nCOST: %.0f\nCooldown: %.1f s" % [
		damage,
		mana_cost,
		cooldown
	]


func _ready() -> void:
	animation_player.play("earthquaker")
	_apply_area_damage_at_impact()


func _apply_area_damage_at_impact() -> void:
	await get_tree().create_timer(animation_player.current_animation_length * damage_animation_ratio).timeout

	if resolved or not is_inside_tree():
		return

	# Aguarda a atualização da física para consultar o colisor existente.
	await get_tree().physics_frame

	var enemies: Array[Node3D] = []
	for body in hit_area.get_overlapping_bodies():
		var enemy := _find_enemy_ancestor(body)
		if not is_instance_valid(enemy) or hit_enemies.has(enemy.get_instance_id()):
			continue
		if enemy.get("dying") == true:
			continue
		var health_value = enemy.get("health")
		if health_value == null or float(health_value) <= 0.0:
			continue
		if not enemy.has_method("take_damage"):
			continue

		hit_enemies[enemy.get_instance_id()] = true
		enemies.append(enemy)

	if enemies.is_empty():
		return

	var raw_damage: float = float(damage)
	if is_instance_valid(character_stats):
		raw_damage += float(character_stats.get_weapon_damage_bonus())
		raw_damage += float(character_stats.get_physical_damage_bonus())

	# Um único resultado crítico para todos os inimigos atingidos, como Arrow Storm.
	var is_critical := false
	if is_instance_valid(character_stats):
		is_critical = character_stats.is_critical_hit()
	if is_critical and is_instance_valid(character_stats):
		raw_damage *= character_stats.get_critical_damage_multiplier()

	var applied_critical_hit := false
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("dying") == true:
			continue
		var health_value = enemy.get("health")
		if health_value == null or float(health_value) <= 0.0:
			continue

		var actual_damage := minf(raw_damage, float(health_value))
		enemy.take_damage(raw_damage, is_critical)
		if is_instance_valid(character_stats):
			character_stats.apply_on_hit_effects(actual_damage)
		if is_critical:
			applied_critical_hit = true

	if applied_critical_hit:
		var camera_pivot := get_tree().get_first_node_in_group("camera_pivot")
		if is_instance_valid(camera_pivot):
			camera_pivot.shake_camera()


func _find_enemy_ancestor(body: Node) -> Node3D:
	var candidate: Node = body
	while is_instance_valid(candidate):
		if candidate.is_in_group("enemies") and candidate is Node3D:
			return candidate as Node3D
		candidate = candidate.get_parent()
	return null


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"earthquaker":
		_finish()


func _finish() -> void:
	if resolved:
		return
	resolved = true
	finished.emit()
	queue_free()
