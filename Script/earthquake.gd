extends Node3D

signal finished

@export_category("Skill")
@export var icon: Texture2D
@export var disabled_icon: Texture2D
@export var cooldown: float = 15.0
@export var mana_cost: float = 35.0

@export_category("Earthquake")
@export var damage: int = 45
@export var damage_delay: float = .9

var character_stats: Node
var resolved: bool = false
var damage_applied: bool = false
var animation_finished: bool = false
var hit_enemies: Dictionary = {}

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_area: Area3D = $Area3D
@onready var hit_shape: CollisionShape3D = $Area3D/CollisionShape3D


func get_description() -> String:
	return "EARTHQUAKE\nDMG: %d + bônus físico\nAREA: linear\nCOST: %.0f\nCooldown: %.1f s" % [
		damage,
		mana_cost,
		cooldown
	]


func _ready() -> void:
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.speed_scale = 2.0
	animation_player.play("earthquaker")
	_apply_area_damage_at_impact()


func _apply_area_damage_at_impact() -> void:
	await get_tree().create_timer(damage_delay).timeout
	if not is_inside_tree():
		return

	var box_shape := hit_shape.shape as BoxShape3D
	if not is_instance_valid(box_shape):
		push_warning("Earthquake: CollisionShape3D precisa usar BoxShape3D.")
		damage_applied = true
		_try_finish_skill()
		return

	# Consulta os inimigos diretamente, usando o volume do colisor existente.
	var enemies: Array[Node3D] = []
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var enemy := candidate as Node3D
		if hit_enemies.has(enemy.get_instance_id()):
			continue
		if enemy.get("dying") == true:
			continue
		var health_value = enemy.get("health")
		if health_value == null or float(health_value) <= 0.0:
			continue
		if not enemy.has_method("take_damage"):
			continue

		# A transformação local respeita posição, rotação e escala da skill.
		var local_position := hit_shape.to_local(enemy.global_position)
		var half_size := box_shape.size * 0.5
		var inside_area := (
			absf(local_position.x) <= half_size.x
			and absf(local_position.y) <= half_size.y + 2.0
			and absf(local_position.z) <= half_size.z
		)
		if not inside_area:
			continue

		hit_enemies[enemy.get_instance_id()] = true
		enemies.append(enemy)

	print("EARTHQUAKE: inimigos dentro da área = ", enemies.size())

	if not enemies.is_empty():
		var raw_damage: float = float(damage)
		if is_instance_valid(character_stats):
			raw_damage += float(character_stats.get_weapon_damage_bonus())
			raw_damage += float(character_stats.get_physical_damage_bonus())

		var is_critical := false
		if is_instance_valid(character_stats):
			is_critical = character_stats.is_critical_hit()
		if is_critical and is_instance_valid(character_stats):
			raw_damage *= character_stats.get_critical_damage_multiplier()

		var applied_critical_hit := false
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.get("dying") == true:
				continue
			var current_health = enemy.get("health")
			if current_health == null or float(current_health) <= 0.0:
				continue

			var actual_damage := minf(raw_damage, float(current_health))
			enemy.take_damage(raw_damage, is_critical)
			if is_instance_valid(character_stats):
				character_stats.apply_on_hit_effects(actual_damage)
			if is_critical:
				applied_critical_hit = true

		if applied_critical_hit:
			var camera_pivot := get_tree().get_first_node_in_group("camera_pivot")
			if is_instance_valid(camera_pivot):
				camera_pivot.shake_camera()

	damage_applied = true
	_try_finish_skill()

func _try_finish_skill() -> void:
	# Não libera nem remove a cena antes de o timer do dano e a animação terminarem.
	if resolved or not damage_applied or not animation_finished:
		return

	resolved = true
	finished.emit()
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(self):
		queue_free()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"earthquaker":
		animation_finished = true
		_try_finish_skill()


func _find_enemy_ancestor(body: Node) -> Node3D:
	var candidate: Node = body
	while is_instance_valid(candidate):
		if candidate.is_in_group("enemies") and candidate is Node3D:
			return candidate as Node3D
		candidate = candidate.get_parent()
	return null
