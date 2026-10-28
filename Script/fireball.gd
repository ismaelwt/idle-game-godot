
extends Node3D

signal finished

@export_category("Skill")
@export var icon: Texture2D
@export var disabled_icon: Texture2D

func get_description() -> String:
	return "FIRE BALL \nDMG: %d\nCOST: %.0f\nCooldown: %.1f s" % [
		damage,
		mana_cost,
		cooldown
	]

@export var cooldown: float = 3.0
@export var mana_cost: float = 20.0

@export_category("Projectile")
@export var speed: float = 5.0
@export var damage: int = 15
@export var damage_multiplier: float = 1.0

var magic_bonus: float = 0.0
var critical_chance: float = 1.0

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

	if target.dying or target.health <= 0:
		finish()
		return

	var target_position: Vector3

	var magic_target = target.get_node_or_null("MagicTarget")

	if magic_target:
		target_position = magic_target.global_position
	else:
		target_position = target.global_position

	var direction = global_position.direction_to(target_position)

	global_position += direction * speed * delta

	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)
		rotation.x += deg_to_rad(-90)


func _on_body_entered(body):
	if resolved:
		return

	var enemy = body.get_parent()

	if enemy.is_in_group("enemies"):
		if enemy.dying or enemy.health <= 0:
			return

		var raw_damage: float = (damage + magic_bonus) * damage_multiplier
		if randf() * 100.0 < critical_chance:
			raw_damage *= 1.5
		var final_damage := int(round(raw_damage))

		enemy.take_damage(final_damage)
		finish()


func finish():
	if resolved:
		return

	resolved = true
	finished.emit()
	queue_free()
