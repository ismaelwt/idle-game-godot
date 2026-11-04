extends Node
class_name MeleeEnemyBehavior

var enemy: Enemy


func _ready() -> void:
	enemy = get_parent() as Enemy
	if not is_instance_valid(enemy):
		push_error("MeleeEnemyBehavior precisa ser filho de Enemy.")
		set_process(false)


func update_behavior(delta: float) -> void:
	if not is_instance_valid(enemy):
		return

	if enemy.dying or enemy.attacking:
		return

	if enemy.in_combat:
		if not enemy.is_valid_combat_target(enemy.combat_target):
			enemy.combat_target = enemy.select_combat_target()

		if not is_instance_valid(enemy.combat_target):
			enemy.in_combat = false
			return

		var enemy_position := Vector2(
			enemy.global_position.x,
			enemy.global_position.z
		)
		var target_position := Vector2(
			enemy.combat_target.global_position.x,
			enemy.combat_target.global_position.z
		)
		var enemy_distance := enemy_position.distance_to(target_position)

		if enemy_distance > enemy.attack_range + 0.01:
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

	var enemy_pos := Vector2(
		enemy.global_position.x,
		enemy.global_position.z
	)
	var target_pos := Vector2(
		target.global_position.x,
		target.global_position.z
	)
	var distance := enemy_pos.distance_to(target_pos)

	if distance <= enemy.attack_range + 0.01:
		enemy.combat_target = target
		start_combat()
		return

	var direction := target.global_position - enemy.global_position
	direction.y = 0.0

	if direction.length_squared() > 0.001:
		if enemy.animation_player.current_animation != enemy.walk_animation:
			enemy.animation_player.play(enemy.walk_animation)

		enemy.look_at_target(target)

		var step_distance: float = minf(
			enemy.speed * delta,
			maxf(distance - enemy.attack_range, 0.0)
		)
		enemy.global_position += direction.normalized() * step_distance


func attack() -> void:
	if not is_instance_valid(enemy) or enemy.attacking or enemy.dying:
		return

	if not enemy.is_valid_combat_target(enemy.combat_target):
		enemy.combat_target = enemy.get_nearest_hero()

	if not is_instance_valid(enemy.combat_target):
		enemy.in_combat = false
		return

	var target: Node3D = enemy.combat_target
	var enemy_pos := Vector2(
		enemy.global_position.x,
		enemy.global_position.z
	)
	var target_pos := Vector2(
		target.global_position.x,
		target.global_position.z
	)
	var distance := enemy_pos.distance_to(target_pos)

	if distance > enemy.attack_range + 0.01:
		enemy.in_combat = false
		enemy.attack_timer = 0.0
		return

	enemy.attacking = true
	enemy.attack_timer = enemy.attack_cooldown
	enemy.animation_player.play(enemy.attack_animation)

	await enemy.get_tree().create_timer(enemy.attack_hit_delay).timeout

	if not is_instance_valid(enemy) or enemy.dying:
		return

	if not enemy.is_valid_combat_target(target):
		enemy.attacking = false
		enemy.in_combat = false
		enemy.combat_target = null
		return

	enemy_pos = Vector2(
		enemy.global_position.x,
		enemy.global_position.z
	)
	target_pos = Vector2(
		target.global_position.x,
		target.global_position.z
	)
	distance = enemy_pos.distance_to(target_pos)

	if distance <= enemy.attack_range + 0.01 and target.has_method("take_damage"):
		target.take_damage(enemy.attack_damage, "physical")

	enemy.attacking = false


func start_combat() -> void:
	if not is_instance_valid(enemy) or enemy.dying or enemy.health <= 0.0:
		return

	if not enemy.is_valid_combat_target(enemy.combat_target):
		enemy.combat_target = enemy.get_nearest_hero()

	if not is_instance_valid(enemy.combat_target):
		return

	enemy.in_combat = true
	enemy.attacking = false
	enemy.attack_timer = 0.0
	enemy.animation_player.speed_scale = 1.0
	enemy.animation_player.play(enemy.idle_animation)
