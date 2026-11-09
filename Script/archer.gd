extends Node3D

@export_category("Ataque")
@export var attack_range: float = 15.0
@export var attack_damage: float = 7.0
@export var attack_cooldown: float = 1.5
@export var attack_hit_delay: float = 0.35
@export var animation_speed: float = 1.0
@export var animation_blend: float = 0.2

@export_category("Vida")
@export var max_health: float = 100.0

@export_category("Dano Visual")
@export var damage_font_size: int = 48
@export var damage_outline_size: int = 8
@export var damage_height: float = 2.5
@export var damage_duration: float = 0.7
@export var damage_color: Color = Color(1.0, 0.2, 0.2, 1.0)

const DAMAGE_FONT: Font = preload("res://Fonts/Pix32.ttf")
const ARROW_PROJECTILE: PackedScene = preload("res://Scenes/arrow_projectile.tscn")
const HEALING_SCENE: PackedScene = preload("res://Scenes/healing_effect.tscn")

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var animation_player_bow: AnimationPlayer = $metarig/Skeleton/BoneAttachment3D/Bow/AnimationPlayer
@onready var character_stats: Node = $CharacterStats
@onready var arrow_spawn: Marker3D = $ArrowSpawn
@onready var level_up_effect: Node3D = get_node_or_null("LevelUpEffect")
@onready var level_controller: Node = get_parent().get_node_or_null("LevelController")
@onready var enemy_spawner: Node = get_parent().get_node_or_null("EnemySpawner")
@onready var world_scroller: Node = get_parent().get_node_or_null("World/WorldScroller")

var health: float = 0.0
var dead: bool = false
var pending_run: bool = false
var attacking: bool = false
var is_running: bool = false
var attack_timer: float = 0.0
var attack_id: int = 0
var current_attack_target: Node3D = null
var initial_rotation_y: float = 0.0


func _ready() -> void:
	set_meta("hero_id", "archer")
	initial_rotation_y = rotation.y
	SaveManager.load_character(
		character_stats,
		character_stats.inventory,
		str(character_stats.hero_id)
	)

	max_health = 100.0 + character_stats.get_max_health_bonus()
	health = max_health
	character_stats.mana = character_stats.max_mana
	character_stats.mana_regen_timer = 0.0

	if not character_stats.attributes_changed.is_connected(_on_attributes_changed):
		character_stats.attributes_changed.connect(_on_attributes_changed)
	if not character_stats.level_up_occurred.is_connected(play_level_up_effect):
		character_stats.level_up_occurred.connect(play_level_up_effect)
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

	animation_player.speed_scale = animation_speed
	play_animation("archer_idle")


func _process(delta: float) -> void:
	if dead:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	if attacking:
		return

	if not is_instance_valid(level_controller):
		play_animation("archer_idle")
		return

	var target: Node3D = null
	var combat_controller := get_parent().get_node_or_null("CombatController")
	if is_instance_valid(combat_controller):
		target = combat_controller.get_valid_target_for_hero(self)

	if not is_instance_valid(target):
		target = find_nearest_enemy_in_detection_range()

	if not is_instance_valid(target):
		if is_instance_valid(world_scroller) and world_scroller.running:
			play_animation("archer_walk")
		else:
			play_animation("archer_idle")
		return

	if is_instance_valid(world_scroller) and world_scroller.running:
		# Durante a corrida, mantém o Archer alinhado à direção inicial do eixo Z.
		rotation.y = initial_rotation_y
		play_animation("archer_walk")
		return

	if not is_enemy_alive(target):
		play_animation("archer_idle")
		return

	look_at_target(target)

	# O CombatController é o único responsável por iniciar ataques.
	# Aqui o Archer apenas mantém a animação de espera quando está no alcance.
	play_animation("archer_idle")


func find_nearest_enemy_in_detection_range() -> Node3D:
	if not is_instance_valid(enemy_spawner):
		return null

	var nearest_enemy: Node3D = null
	var nearest_distance := attack_range

	for enemy in enemy_spawner.enemies:
		if not is_instance_valid(enemy) or not is_enemy_alive(enemy):
			continue

		var distance := get_horizontal_distance_to(enemy)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy


func is_enemy_alive(target: Node) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if target.get("dying") == true:
		return false
	var target_health = target.get("health")
	return target_health != null and float(target_health) > 0.0


func get_horizontal_distance_to(target: Node3D) -> float:
	if not is_instance_valid(target):
		return INF
	return Vector2(global_position.x, global_position.z).distance_to(
		Vector2(target.global_position.x, target.global_position.z)
	)


func _notify_skill_cancelled() -> void:
	var controller := get_parent().get_node_or_null("CombatController")
	if is_instance_valid(controller) and controller.has_method("on_hero_skill_cancelled"):
		controller.on_hero_skill_cancelled(self)

func can_use_skill(skill_id: String, target: Node3D) -> bool:
	if dead or not is_enemy_alive(target):
		return false

	match skill_id:
		"arrow_storm":
			if not animation_player.has_animation("archer/archer_skill_1"):
				return false
			var storm_scene: PackedScene = preload("res://Scenes/arrow_storm.tscn")
			if storm_scene == null:
				return false
			var test_storm := storm_scene.instantiate()
			if not is_instance_valid(test_storm):
				return false
			test_storm.free()
		"archer_heal":
			if HEALING_SCENE == null:
				return false
			var test_heal := HEALING_SCENE.instantiate()
			if not is_instance_valid(test_heal):
				return false
			test_heal.free()
			if not animation_player.has_animation("archer/archer_heal"):
				return false
		_:
			return false

	return true


func use_skill(skill_id: String, target: Node3D) -> void:
	if pending_run or not can_use_skill(skill_id, target):
		return

	if skill_id == "arrow_storm":
		_use_arrow_storm(target)
		return

	if skill_id != "archer_heal":
		push_warning("Skill desconhecida no Archer: " + skill_id)
		return

	# Invalida qualquer ataque básico que ainda esteja aguardando o disparo.
	attack_id += 1
	var my_attack_id: int = attack_id

	attacking = true
	current_attack_target = null

	print("ARCHER -> SKILL HEAL")

	# A cura só é aplicada depois que a animação termina.
	# Se a skill for interrompida durante a preparação, não haverá
	# efeito aplicado e o CombatController poderá devolver mana/cooldown.

	# Mantém attacking ativo para impedir que _process() substitua
	# a animação de cura pelo idle antes de ela terminar.
	var heal_animation := "archer/archer_heal"
	if animation_player.has_animation(heal_animation):
		animation_player.speed_scale = animation_speed
		animation_player.play(heal_animation, animation_blend)
		await animation_player.animation_finished
	else:
		push_warning("Archer: animação não encontrada: " + heal_animation)

	if my_attack_id != attack_id or dead:
		return

	# Confirma a execução da cura somente após a preparação ser concluída.
	var healing_instance := HEALING_SCENE.instantiate()
	if not is_instance_valid(healing_instance):
		_notify_skill_cancelled()
		attacking = false
		current_attack_target = null
		return

	get_tree().current_scene.add_child(healing_instance)
	healing_instance.global_position = global_position

	var old_health: float = health
	health = minf(health + float(healing_instance.healing_amount), max_health)
	var healed_amount: float = health - old_health

	print("=== CURA DO ARCHER APLICADA ===")
	print("Vida recuperada: ", healed_amount)
	print("Vida atual: ", health, "/", max_health)

	# A cura permanece ativa visualmente durante sua duração, mas não bloqueia
	# o Archer: depois da animação de ativação ele já pode atacar ou usar outra skill.
	_remove_healing_effect_after_duration(healing_instance)

	attacking = false
	current_attack_target = null

	if is_instance_valid(world_scroller) and world_scroller.running:
		rotation.y = initial_rotation_y
		animation_player.speed_scale = 1.0
		play_animation("archer_walk")
	else:
		play_animation("archer_idle")


func _remove_healing_effect_after_duration(healing_instance: Node) -> void:
	if not is_instance_valid(healing_instance):
		return

	var duration_value = healing_instance.get("duration")
	if duration_value == null:
		healing_instance.queue_free()
		return

	await get_tree().create_timer(maxf(float(duration_value), 0.0)).timeout
	if is_instance_valid(healing_instance):
		healing_instance.queue_free()


func _use_arrow_storm(target: Node3D) -> void:
	attack_id += 1
	var my_attack_id := attack_id

	attacking = true
	current_attack_target = null
	look_at_target(target)

	var skill_animation := "archer/archer_skill_1"
	if not animation_player.has_animation(skill_animation):
		push_warning("Archer: animação não encontrada: " + skill_animation)
		attacking = false
		return

	animation_player.speed_scale = 1.0
	animation_player.play(skill_animation, animation_blend)

	# Guarda o ponto de impacto no início: se o alvo morrer durante a
	# preparação, a chuva de flechas ainda acontece nessa posição.
	var skill_center_position := target.global_position

	# Usa o mesmo tempo de disparo dos ataques do Archer e do EnemyArcher.
	await get_tree().create_timer(attack_hit_delay).timeout

	if my_attack_id != attack_id or dead or not is_inside_tree():
		return

	var storm := preload("res://Scenes/arrow_storm.tscn").instantiate()
	storm.center_target = target
	storm.center_position = skill_center_position
	storm.has_center_position = true
	storm.shooter = self
	storm.character_stats = character_stats
	storm.damage = (
		float(storm.damage)
		+ float(character_stats.get_physical_damage_bonus())
		+ float(character_stats.get_weapon_damage_bonus())
	)

	# Conecta antes de adicionar à árvore: _ready() da ArrowStorm pode
	# finalizar imediatamente (por exemplo, sem inimigos na área).
	# Se aguardarmos o sinal somente depois de add_child(), podemos perdê-lo
	# e deixar attacking=true, impedindo o início do running.
	storm.finished.connect(
		_on_arrow_storm_finished.bind(my_attack_id),
		CONNECT_ONE_SHOT
	)
	get_tree().current_scene.add_child(storm)


func _on_arrow_storm_finished(skill_attack_id: int) -> void:
	if skill_attack_id != attack_id or dead:
		return

	attacking = false
	current_attack_target = null

	if is_instance_valid(world_scroller) and world_scroller.running:
		rotation.y = initial_rotation_y
		play_animation("archer_walk")
	else:
		play_animation("archer_idle")


func start_running() -> void:
	if dead:
		return
	if attacking:
		# A corrida será retomada pelo callback da skill assim que o efeito
		# terminar; não interrompe a animação/execução da habilidade.
		is_running = true
		return

	# Mesmo fluxo de transição usado pelo Mage ao iniciar a corrida.
	current_attack_target = null
	is_running = true

	rotation.y = initial_rotation_y
	animation_player.speed_scale = 1.0
	play_animation("archer_walk")


func basic_attack(target: Node3D) -> void:
	if dead or pending_run or attacking or not is_enemy_alive(target):
		return
	if get_horizontal_distance_to(target) > attack_range + 0.01:
		return

	attacking = true
	current_attack_target = target
	attack_id += 1
	var current_id := attack_id

	var interval_multiplier: float = character_stats.get_basic_attack_interval_multiplier()
	attack_timer = attack_cooldown * interval_multiplier
	var target_position_snapshot: Vector3 = target.global_position

	look_at_target(target)
	play_animation("archer_attack2")
	animation_player_bow.play("Armature|Bow_Fire")

	await get_tree().create_timer(attack_hit_delay).timeout

	if current_id != attack_id or dead or not is_inside_tree():
		return
	# Dispara mesmo se o alvo morreu durante a preparação.
	# A flecha termina o percurso visual sem aplicar dano ao alvo morto.

	var raw_damage: float = (
		attack_damage
		+ character_stats.get_physical_damage_bonus()
		+ character_stats.get_weapon_damage_bonus()
	)
	var is_critical: bool = character_stats.is_critical_hit()
	var final_damage := raw_damage
	if is_critical:
		final_damage *= character_stats.get_critical_damage_multiplier()

	AudioManager.play_sfx(preload("res://Sounds/arrow_shot.mp3"), randf_range(0.95, 1.05))

	var projectile := ARROW_PROJECTILE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = arrow_spawn.global_position
	projectile.global_rotation = arrow_spawn.global_rotation
	projectile.scale = Vector3(.4, .4, .4)
	projectile.setup(target if is_instance_valid(target) else null, self, final_damage, is_critical)
	projectile.target_position_snapshot = target_position_snapshot
	projectile.has_target_position_snapshot = true
	# Mantém attacking=true até a animação de disparo terminar,
	# como no EnemyArcher. O sinal animation_finished libera o próximo ataque.


func _finish_attack() -> void:
	attacking = false
	current_attack_target = null
	if not dead:
		play_animation("archer_idle")


func play_animation(animation_name: String) -> void:
	var full_name := "archer/" + animation_name
	if animation_player.current_animation == full_name and animation_player.is_playing():
		return
	if animation_player.has_animation(full_name):
		animation_player.speed_scale = animation_speed
		if animation_name == "archer_attack2":
			animation_player.speed_scale = 2.0
			animation_player_bow.play("Armature|Bow_Fire")
		var blend_time := 0.0 if animation_name == "archer_walk" else animation_blend
		animation_player.play(full_name, blend_time)


func look_at_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		rotation.y = atan2(direction.x, direction.z)


func take_damage(damage: float, damage_type: String = "physical") -> void:
	if dead:
		return
	var final_damage: float = character_stats.calculate_damage_after_defense(damage, damage_type)
	health = maxf(health - final_damage, 0.0)
	show_damage(final_damage)
	flash_hit()
	if health <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	_notify_skill_cancelled()
	attack_id += 1
	attacking = false
	current_attack_target = null
	animation_player.speed_scale = 1.0
	if animation_player.has_animation("archer/archer_die"):
		animation_player.play("archer/archer_die", animation_blend)
	else:
		_finish_death()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == "archer/archer_attack2" and not dead:
		_finish_attack()
	elif animation_name == "archer/archer_die":
		_finish_death()


func _finish_death() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	for collision_node in find_children("*", "CollisionShape3D", true, false):
		collision_node.set_deferred("disabled", true)
	for area_node in find_children("*", "Area3D", true, false):
		area_node.set_deferred("monitoring", false)
		area_node.set_deferred("monitorable", false)


func _on_attributes_changed() -> void:
	var old_max_health := max_health
	max_health = 100.0 + character_stats.get_max_health_bonus()
	health = clampf(health + maxf(max_health - old_max_health, 0.0), 0.0, max_health)


func play_level_up_effect() -> void:
	if not is_instance_valid(level_up_effect):
		return
	level_up_effect.visible = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(level_up_effect):
		level_up_effect.visible = false


func show_damage(damage: float) -> void:
	var label := Label3D.new()
	label.text = "-" + str(int(damage))
	label.font = DAMAGE_FONT
	label.font_size = damage_font_size
	label.outline_size = damage_outline_size
	label.modulate = damage_color
	label.no_depth_test = true
	label.render_priority = 3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	label.top_level = true
	var start_position := global_position + Vector3(0.0, damage_height, 0.0)
	label.global_position = start_position
	var elapsed := 0.0
	while elapsed < damage_duration and is_instance_valid(label) and is_inside_tree():
		elapsed += get_process_delta_time()
		var progress := clampf(elapsed / damage_duration, 0.0, 1.0)
		label.global_position = start_position + Vector3(0.0, sin(PI * progress) * 1.2, 0.0)
		await get_tree().process_frame
	if is_instance_valid(label):
		label.queue_free()


func flash_hit() -> void:
	var meshes = find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)

	for _i in range(2):
		for mesh in meshes:
			if not is_instance_valid(mesh):
				continue

			if is_instance_valid(level_up_effect):
				if mesh == level_up_effect or level_up_effect.is_ancestor_of(mesh):
					continue

			var material = mesh.get_active_material(0)

			if material == null or material is ShaderMaterial:
				continue

			var flash_material = material.duplicate()
			flash_material.albedo_color = Color(1.0, 0.03, 0.03, 1.0)
			flash_material.emission_enabled = true
			flash_material.emission = Color(1.0, 0.0, 0.0, 1.0)
			flash_material.emission_energy_multiplier = 3.0

			mesh.material_override = flash_material

		await get_tree().create_timer(0.08).timeout

		for mesh in meshes:
			if not is_instance_valid(mesh):
				continue

			if is_instance_valid(level_up_effect):
				if mesh == level_up_effect or level_up_effect.is_ancestor_of(mesh):
					continue

			mesh.material_override = null

		await get_tree().create_timer(0.05).timeout
