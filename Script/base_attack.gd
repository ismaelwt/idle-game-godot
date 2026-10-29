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

var target: Node3D
var resolved := false


func _ready():

	$Area3D.body_entered.connect(_on_body_entered)



func _process(delta):

	if resolved:
		return

	if not is_instance_valid(target):
		finish()
		return

	# Cancela o projétil assim que a morte começa.
	if target.dying or target.health <= 0:
		finish()
		return

	# Não continua perseguindo um alvo que saiu da cena.
	if not target.is_inside_tree():
		finish()
		return

	var target_position: Vector3

	var magic_target = target.get_node_or_null("MagicTarget")

	if is_instance_valid(magic_target):
		target_position = magic_target.global_position
	else:
		target_position = target.global_position

	var direction = global_position.direction_to(target_position)

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
		finish()
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
	var final_damage := int(round(raw_damage))

	target.take_damage(final_damage, is_critical)

	finish()


func finish():

	if resolved:
		return

	resolved = true

	finished.emit()

	queue_free()
