
extends Node3D

@export_category("Movimento")
@export var speed: float = 18.0
@export var max_lifetime: float = 5.0

@export_category("Dano")
@export var damage: float = 10.0

var target: Node3D = null
var shooter: Node3D = null
var lifetime: float = 0.0
var resolved: bool = false

@onready var area: Area3D = $Arrow/Area3D


func _ready() -> void:
	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)


func setup(
	target_node: Node3D,
	shooter_node: Node3D,
	projectile_damage: float
) -> void:
	target = target_node
	shooter = shooter_node
	damage = projectile_damage


func _process(delta: float) -> void:
	if resolved:
		return

	lifetime += delta

	if lifetime >= max_lifetime:
		finish()
		return

	if not is_instance_valid(target):
		finish()
		return

	if target.get("dead") == true:
		finish()
		return

	var target_position: Vector3 = target.global_position
	var magic_target: Node3D = target.get_node_or_null("MagicTarget")

	if is_instance_valid(magic_target):
		target_position = magic_target.global_position
	else:
		target_position.y += 1.0

	var to_target: Vector3 = target_position - global_position
	var distance: float = to_target.length()

	if distance <= 0.001:
		apply_target_damage()
		return

	var direction: Vector3 = to_target / distance
	var movement: Vector3 = direction * speed * delta

	# Compensa o deslocamento do cenário.
	var world_scroller = get_tree().get_first_node_in_group("world_scroller")

	if is_instance_valid(world_scroller) and world_scroller.running:
		movement.z -= world_scroller.speed * delta

	if movement.length() >= distance:
		global_position = target_position
		apply_target_damage()
	else:
		global_position += movement

func _on_body_entered(body: Node3D) -> void:
	if resolved:
		return

	# Ignora o arqueiro que disparou e seus componentes.
	if is_instance_valid(shooter):
		if body == shooter or shooter.is_ancestor_of(body):
			return

	# Ignora corpos que não pertencem ao alvo definido.
	if not is_instance_valid(target):
		finish()
		return

	var node: Node = body

	while node != null:
		# Só permite dano ao alvo desta flecha.
		if node == target:
			if target.get("dead") != true:
				apply_target_damage()
			else:
				finish()
			return

		node = node.get_parent()

	# Outro inimigo ou objeto está no caminho:
	# ignora a colisão e deixa a flecha continuar.

func apply_target_damage() -> void:
	if resolved:
		return

	if not is_instance_valid(target):
		finish()
		return

	if target.get("dead") == true:
		finish()
		return

	if target.has_method("take_damage"):
		target.call("take_damage", damage)

	finish()


func finish() -> void:
	if resolved:
		return

	resolved = true
	queue_free()
