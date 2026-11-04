extends Node
class_name BossEnemyBehavior

@export_category("Ataque Especial")
@export_range(1.0, 10.0, 0.5) var special_attack_damage_multiplier: float = 2.5
@export_range(0.0, 1.0, 0.05) var special_attack_health_threshold: float = 0.5

var enemy: Enemy
var special_attack_used: bool = false
var special_attack_in_progress: bool = false


func _ready() -> void:
	enemy = get_parent() as Enemy
	if not is_instance_valid(enemy):
		push_error("BossEnemyBehavior precisa ser filho de Enemy.")
		set_process(false)


func update_behavior(delta: float) -> void:
	if not is_instance_valid(enemy) or enemy.dying or enemy.attacking:
		return

	if enemy.in_combat:
		if not enemy.is_valid_combat_target(enemy.combat_target):
			enemy.combat_target = enemy.get_nearest_hero()

		if not is_instance_valid(enemy.combat_target):
			enemy.in_combat = false
			return

		if _distance_to(enemy.combat_target) > enemy.attack_range + 0.01:
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

	var distance := _distance_to(target)
	if distance <= enemy.attack_range:
		enemy.combat_target = target
		start_combat()
		return

	var direction := target.global_position - enemy.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return

	if enemy.animation_player.current_animation != enemy.walk_animation:
		enemy.animation_player.play(enemy.walk_animation)

	enemy.look_at_target(target)
	enemy.global_position += direction.normalized() * enemy.speed * delta


func on_enemy_damaged() -> void:
	if not is_instance_valid(enemy) or enemy.dying or special_attack_used:
		return
	if enemy.max_health <= 0.0:
		return

	if enemy.health <= enemy.max_health * special_attack_health_threshold:
		special_attack_used = true
		_special_attack()


func _special_attack() -> void:
	if not is_instance_valid(enemy) or enemy.dying:
		return

	special_attack_in_progress = true
	enemy.attacking = true
	enemy.attack_timer = enemy.attack_cooldown
	enemy.animation_player.play("enemy/boss_especial_attack")

	await enemy.get_tree().create_timer(enemy.attack_hit_delay).timeout

	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.dying:
		return

	var target := enemy.get_nearest_hero()
	if is_instance_valid(target):
		var special_damage := enemy.attack_damage * special_attack_damage_multiplier
		if target.has_method("take_damage") and _distance_to(target) <= enemy.attack_range + 1.0:
			target.take_damage(special_damage, "physical")


func attack() -> void:
	if not is_instance_valid(enemy) or enemy.attacking or enemy.dying:
		return

	var target := enemy.combat_target
	if not enemy.is_valid_combat_target(target):
		target = enemy.get_nearest_hero()
		enemy.combat_target = target

	if not is_instance_valid(target) or _distance_to(target) > enemy.attack_range + 0.01:
		enemy.in_combat = false
		enemy.attack_timer = 0.0
		return

	enemy.attacking = true
	enemy.attack_timer = enemy.attack_cooldown
	enemy.animation_player.play(enemy.attack_animation)

	await enemy.get_tree().create_timer(enemy.attack_hit_delay).timeout

	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.dying:
		return

	if enemy.is_valid_combat_target(target) and _distance_to(target) <= enemy.attack_range + 0.01:
		if target.has_method("take_damage"):
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


func _distance_to(target: Node3D) -> float:
	if not is_instance_valid(enemy) or not is_instance_valid(target):
		return INF
	var a := Vector2(enemy.global_position.x, enemy.global_position.z)
	var b := Vector2(target.global_position.x, target.global_position.z)
	return a.distance_to(b)
