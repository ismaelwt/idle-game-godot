
extends Node3D

signal finished

@export_category("Skill")
@export var icon: Texture2D
@export var disabled_icon: Texture2D

@export var cooldown: float = 8.0
@export var mana_cost: float = 35.0

@export_category("Thunderstorm")
@export var damage: int = 20
@export var radius: float = 8.0
@export var strike_height: float = 7.0
@export var strike_duration: float = 3.0

@export_category("Cloud Animation")
@export var cloud_move_radius: float = 5.0
@export var cloud_change_interval: float = 0.2

var magic_bonus: float = 0.0
var critical_chance: float = 1.0
var critical_damage_multiplier: float = 1.5
var damage_multiplier: float = 1.0

var center_target: Node3D
var resolved: bool = false
var storm_ended: bool = false
var fixed_cloud_position: Vector3

var cloud_sources: Array[Node3D] = []
var created_bolts: Array[Node3D] = []

@onready var lightning_template: Node3D = $Bolts
@onready var cloud: Node3D = $Cloud


func get_description() -> String:
	return "THUNDERSTORM\nDMG: %d\nAREA: %.1f\nCOST: %.0f\nCooldown: %.1f s" % [
		damage + magic_bonus,
		radius,
		mana_cost,
		cooldown
	]


func _ready() -> void:
	randomize()

	lightning_template.visible = false

	cloud_sources.clear()
	
	_resolve_storm()


func _resolve_storm() -> void:
	if resolved:
		return

	resolved = true

	if not is_instance_valid(center_target):
		_finish_after_delay()
		return

	# Registra a posição inicial da tempestade.
	var center_position: Vector3 = center_target.global_position

	fixed_cloud_position = (
		center_position + Vector3.UP * strike_height
	)

	# Localiza o WorldScroller.
	var world_scroller: Node3D = get_tree().current_scene.find_child(
		"WorldScroller", true, false
	) as Node3D

	if world_scroller == null:
		push_error("Thunderstorm: não encontrei o WorldScroller.")
		_finish_after_delay()
		return

	# A nuvem acompanha o movimento do cenário.
	cloud.reparent(world_scroller, true)
	cloud.global_position = fixed_cloud_position

	# Procura os inimigos dentro da área.
	var enemies: Array[Node] = []
	var nodes: Array[Node] = get_tree().get_nodes_in_group("enemies")

	for enemy in nodes:
		if not is_instance_valid(enemy):
			continue

		if not enemy.has_method("take_damage"):
			continue

		if enemy.get("dying") == true:
			continue

		var health = enemy.get("health")

		if health == null or float(health) <= 0.0:
			continue

		var enemy_position: Vector3 = enemy.global_position

		var horizontal_distance: float = Vector2(
			enemy_position.x - center_position.x,
			enemy_position.z - center_position.z
		).length()

		if horizontal_distance <= radius:
			enemies.append(enemy)

	# Cria apenas 3 raios visuais por tempestade.
	var bolt_targets: Array[Node] = []

	for enemy in enemies:
		if is_instance_valid(enemy):
			if enemy.get("dying") != true:
				var health = enemy.get("health")
				if health != null and float(health) > 0.0:
					bolt_targets.append(enemy)

	var bolt_count: int = mini(3, bolt_targets.size())

	for i in range(bolt_count):
		var target_index: int = int(
			round(float(i) * float(bolt_targets.size() - 1) / float(maxi(bolt_count - 1, 1)))
		)
		_create_lightning(bolt_targets[target_index])

	# O dano continua sendo aplicado a todos os inimigos na área.
	var raw_damage: float = (damage + magic_bonus) * damage_multiplier
	var is_critical: bool = randf() * 100.0 < critical_chance
	if is_critical:
		raw_damage *= critical_damage_multiplier
	var final_damage: int = int(round(raw_damage))

	for enemy in bolt_targets:
		if is_instance_valid(enemy):
			if enemy.get("dying") != true:
				var health = enemy.get("health")
				if health != null and float(health) > 0.0:
					enemy.take_damage(final_damage, is_critical)
	
	_finish_after_delay()



func _randomize_cloud_position(cloud_node: Node3D) -> void:
	cloud_node.position = Vector3(
		randf_range(-cloud_move_radius, cloud_move_radius),
		randf_range(-0.5, 0.5),
		randf_range(-cloud_move_radius, cloud_move_radius)
	)



func _create_lightning(enemy: Node3D) -> void:
	var target_position: Vector3

	var magic_target: Node3D = enemy.get_node_or_null("MagicTarget")

	if magic_target != null:
		target_position = magic_target.global_position
	else:
		target_position = enemy.global_position + Vector3.UP

	# O raio começa diretamente acima do alvo.
	var start_position: Vector3 = target_position + Vector3.UP * 8.0

	# Direção exclusivamente vertical, para baixo.
	var direction: Vector3 = Vector3.DOWN
	var distance: float = start_position.distance_to(target_position)

	if distance <= 0.001:
		return

	var bolt: Node3D = lightning_template.duplicate() as Node3D

	if bolt == null:
		return

	# Mantém os raios no mesmo espaço da nuvem e do cenário.
	cloud.get_parent().add_child(bolt)

	bolt.visible = true
	bolt.global_position = start_position
	bolt.quaternion = Quaternion(Vector3.UP, direction)

	# Guarda a referência para remover o raio ao fim da skill.
	created_bolts.append(bolt)

	var mesh_node := bolt.get_node_or_null("Mesh3D") as MeshInstance3D

	if mesh_node != null and mesh_node.mesh != null:
		var mesh_height: float = mesh_node.mesh.get_aabb().size.y

		if mesh_height > 0.001:
			bolt.scale.y *= distance / mesh_height



func _finish_after_delay() -> void:
	await get_tree().create_timer(strike_duration).timeout

	storm_ended = true

	# Remove somente os raios desta tempestade.
	for bolt in created_bolts:
		if is_instance_valid(bolt):
			bolt.queue_free()

	created_bolts.clear()

	# Remove a nuvem principal e suas nuvens secundárias.
	if is_instance_valid(cloud):
		cloud.queue_free()

	finished.emit()
	queue_free()
