extends Node3D

signal finished

@export_category("Projectile")
@export var speed: float = 3.0
@export var damage: int = 5
@export var damage_multiplier: float = 1.0

var magic_bonus: int = 0
var critical_chance: float = 1.0
var critical_damage_multiplier: float = 1.5
var basic_attack_level: int = 0
var character_stats: Node

var target: Node3D
var target_position_snapshot: Vector3 = Vector3.ZERO
var has_target_position_snapshot: bool = false
var resolved := false


func _ready():

	$Area3D.body_entered.connect(_on_body_entered)



func _process(delta):

	if resolved:
		return

	var target_is_alive := (
		is_instance_valid(target)
		and target.is_inside_tree()
		and not target.dying
		and target.health > 0
	)

	if not target_is_alive and not has_target_position_snapshot:
		finish()
		return

	var target_position: Vector3 = target_position_snapshot

	if target_is_alive:
		var magic_target = target.get_node_or_null("MagicTarget")
		if is_instance_valid(magic_target):
			target_position = magic_target.global_position
		else:
			target_position = target.global_position

	var direction_to_last_position := global_position.direction_to(target_position)
	if not target_is_alive and global_position.distance_to(target_position) <= speed * delta:
		finish()
		return

	var direction = direction_to_last_position if not target_is_alive else global_position.direction_to(target_position)

	global_position += direction * speed * delta

	if direction.length() > 0.01:
		look_at(
			global_position + direction,
			Vector3.UP
		)

		rotation.x += deg_to_rad(-90)




func _on_body_entered(body):

	if resolved:
		return

	if not is_instance_valid(target):
		# Sem referência ao alvo original, não há outro inimigo que possa
		# receber este ataque básico. O projétil segue visualmente até a posição salva.
		return

	# O projétil só pode acertar o alvo para o qual foi lançado.
	var enemy = body

	if not enemy.is_in_group("enemies"):
		enemy = body.get_parent()

	if enemy != target:
		return

	# Impede acertar um alvo que já morreu ou está morrendo.
	if target.dying or target.health <= 0:
		finish()
		return

	var raw_damage: float = (damage + basic_attack_level + magic_bonus) * damage_multiplier
	var is_critical: bool = randf() * 100.0 < critical_chance
	if is_critical:
		raw_damage *= critical_damage_multiplier
		var camera_pivot := get_tree().get_first_node_in_group("camera_pivot")
		if is_instance_valid(camera_pivot):
			camera_pivot.shake_camera()
	var final_damage := int(round(raw_damage))
	var health_before_hit := maxf(float(target.health), 0.0)
	var actual_damage := minf(float(final_damage), health_before_hit)
	target.take_damage(final_damage, is_critical)
	if is_instance_valid(character_stats):
		character_stats.apply_on_hit_effects(actual_damage)

	finish()


func finish():

	if resolved:
		return

	resolved = true

	finished.emit()

	queue_free()
