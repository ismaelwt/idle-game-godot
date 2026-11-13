extends Node
class_name ArcherEnemyBehavior

var enemy: Enemy
var arrow_spawn: Node3D


func _ready() -> void:
	enemy = get_parent() as Enemy
	if not is_instance_valid(enemy):
		push_error("ArcherEnemyBehavior precisa ser filho de Enemy.")
		set_process(false)
		return

	arrow_spawn = enemy.get_node_or_null("ArrowSpawn") as Node3D
	if not is_instance_valid(arrow_spawn):
		push_error("ArcherEnemyBehavior: nó ArrowSpawn não encontrado em " + enemy.name)
		set_process(false)


func update_behavior(delta: float) -> void:
	if not is_instance_valid(enemy) or enemy.dying or enemy.attacking:
		return

	if enemy.in_combat:
		if not enemy.is_valid_combat_target(enemy.combat_target):
			enemy.combat_target = enemy.select_combat_target()

		if not is_instance_valid(enemy.combat_target):
			enemy.in_combat = false
			return

		if get_horizontal_distance_to(enemy.combat_target) > enemy.attack_range + 0.01:
			enemy.in_combat = false
			enemy.attack_timer = 0.0
			return

		enemy.attack_timer -= delta
		if enemy.attack_timer <= 0.0:
			attack()
		return

	var target := enemy.get_nearest_hero()
	if not is_instance_valid(target):
		return

	var distance := get_horizontal_distance_to(target)

	if distance <= enemy.attack_range or not enemy.approach_enabled:
		enemy.combat_target = target
		enemy.look_at_target(target)
		start_combat()
		enemy.request_combat_engagement()
		return

	var direction := target.global_position - enemy.global_position
	direction.y = 0.0

	if direction.length_squared() > 0.001:
		enemy.look_at_target(target)

	if enemy.animation_player.current_animation != enemy.walk_animation:
		enemy.animation_player.play(enemy.walk_animation)

	var step_distance: float = minf(
		enemy.speed * delta,
		distance - enemy.attack_range
	)
	enemy.global_position += direction.normalized() * step_distance


func get_horizontal_distance_to(target: Variant) -> float:
	if not is_instance_valid(enemy) or not is_instance_valid(target) or not target is Node3D:
		return INF

	var enemy_pos := Vector2(enemy.global_position.x, enemy.global_position.z)
	var target_pos := Vector2(target.global_position.x, target.global_position.z)
	return enemy_pos.distance_to(target_pos)


func attack() -> void:
	if not is_instance_valid(enemy) or enemy.attacking or enemy.dying or not enemy.in_combat:
		return

	if not enemy.is_valid_combat_target(enemy.combat_target):
		enemy.combat_target = enemy.select_combat_target()

	if not is_instance_valid(enemy.combat_target):
		enemy.in_combat = false
		return

	var target: Node3D = enemy.combat_target

	if get_horizontal_distance_to(target) > enemy.attack_range + 0.01:
		enemy.in_combat = false
		enemy.attack_timer = 0.0
		return

	if enemy.projectile_scene == null:
		push_warning("Arqueiro sem projectile_scene configurada: " + enemy.name)
		enemy.attack_timer = enemy.attack_cooldown
		return

	if not is_instance_valid(arrow_spawn):
		push_warning("Arqueiro sem ArrowSpawn: " + enemy.name)
		enemy.attack_timer = enemy.attack_cooldown
		return

	enemy.look_at_target(target)
	enemy.attacking = true
	enemy.attack_timer = enemy.attack_cooldown
	enemy.animation_player.play(enemy.attack_animation)

	await enemy.get_tree().create_timer(enemy.attack_hit_delay).timeout

	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.dying:
		return

	if not enemy.is_valid_combat_target(target):
		_finish_attack()
		enemy.combat_target = enemy.select_combat_target()
		if not is_instance_valid(enemy.combat_target):
			enemy.in_combat = false
		return

	if get_horizontal_distance_to(target) > enemy.attack_range + 0.01:
		_finish_attack()
		enemy.in_combat = false
		return

	var projectile = enemy.projectile_scene.instantiate()
	var projectile_parent: Node = enemy.get_tree().current_scene

	if projectile_parent == null:
		projectile_parent = enemy.get_parent()

	if projectile_parent == null:
		projectile.queue_free()
		_finish_attack()
		return

	projectile_parent.add_child(projectile)
	projectile.global_position = arrow_spawn.global_position
	projectile.global_rotation = arrow_spawn.global_rotation

	if projectile.has_method("setup"):
		projectile.setup(target, enemy, enemy.attack_damage)
	else:
		push_warning("O projétil não possui o método setup(): " + projectile.name)
		projectile.queue_free()

	_finish_attack()


func _finish_attack() -> void:
	if not is_instance_valid(enemy):
		return

	enemy.attacking = false
	if enemy.dying:
		return

	if is_instance_valid(enemy.animation_player):
		enemy.animation_player.play(enemy.idle_animation)


func start_combat() -> void:
	if not is_instance_valid(enemy) or enemy.dying or enemy.health <= 0.0:
		return

	if not enemy.is_valid_combat_target(enemy.combat_target):
		enemy.combat_target = enemy.select_combat_target()

	if not is_instance_valid(enemy.combat_target):
		enemy.combat_target = enemy.get_nearest_hero()

	if not is_instance_valid(enemy.combat_target):
		return

	enemy.in_combat = true
	enemy.request_combat_engagement()
	enemy.attacking = false
	enemy.attack_timer = 0.0
	enemy.animation_player.speed_scale = 1.0
	enemy.animation_player.play(enemy.idle_animation)
