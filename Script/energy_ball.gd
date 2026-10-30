extends Node3D

signal finished

@export_category("Skill")
@export var icon: Texture2D
@export var disabled_icon: Texture2D

func get_description() -> String:
	return "ENERGY BALL \nDMG: %d\nCOST: %.0f\nCooldown: %.1f s" % [
		damage,
		mana_cost,
		cooldown
	]
@export var cooldown: float = 5.0
@export var mana_cost: float = 35.0

@export_category("Projectile")
@export var speed: float = 5.0
@export var target_height: float = 1.5

@export_category("Damage")
@export var damage: int = 45
@export var damage_multiplier: float = 1.0

var magic_bonus: float = 0.0
var critical_chance: float = 1.0
var critical_damage_multiplier: float = 1.5
var character_stats: Node

@export_category("Explosão")
@export var explosion_radius: float = 3.0

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

		var up_direction = Vector3.UP

		var look_basis = Basis.looking_at(direction, up_direction)

		global_transform.basis = look_basis * Basis(
			Vector3.RIGHT,
			deg_to_rad(-90)
		)



func _on_body_entered(body: Node3D) -> void:
	if resolved:
		return

	# Procura o inimigo no próprio corpo ou nos seus ancestrais.
	var enemy: Node = body

	while enemy != null and not enemy.is_in_group("enemies"):
		enemy = enemy.get_parent()

	if enemy == null:
		return

	# Confere se o nó encontrado possui as propriedades esperadas.
	if not ("dying" in enemy and "health" in enemy):
		return

	# Ignora inimigos mortos ou que estão morrendo.
	if enemy.dying or enemy.health <= 0:
		return

	explode(enemy.global_position)



func finish():

	if resolved:
		return

	resolved = true

	finished.emit()

	queue_free()



func explode(explosion_position: Vector3) -> void:
	if resolved:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")

	var raw_damage: float = (damage + magic_bonus) * damage_multiplier
	var is_critical: bool = randf() * 100.0 < critical_chance
	if is_critical:
		raw_damage *= critical_damage_multiplier
	var final_damage := int(round(raw_damage))

	for node in enemies:
		if not is_instance_valid(node):
			continue

		# Ignora qualquer nó que não seja um inimigo válido.
		if not node is Node3D:
			continue

		if not ("dying" in node and "health" in node):
			continue

		if not node.has_method("take_damage"):
			continue

		if node.dying or node.health <= 0:
			continue

		var distance: float = explosion_position.distance_to(
			node.global_position
		)

		if distance <= explosion_radius:
			var health_before_hit := maxf(float(node.health), 0.0)
			var actual_damage := minf(float(final_damage), health_before_hit)
			node.take_damage(final_damage, is_critical)
			if is_instance_valid(character_stats):
				character_stats.apply_on_hit_effects(actual_damage)

	finish()
