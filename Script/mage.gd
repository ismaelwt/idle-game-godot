extends Node3D

@export_category("Attack Range")
@export var attack_range: float = 8.0

@export_category("Attack Base")
@export var attack_base_duration: float = 0.5
@export var animation_player_attack_base_duration: float = 1.5


@export_category("Dano Visual")
@export var damage_font_size: int = 48
@export var damage_outline_size: int = 8
@export var damage_height: float = 2.5
@export var damage_duration: float = 0.7
@export var damage_color: Color = Color(1, 0.2, 0.2, 1)


@export_category("Vida")
@export var max_health: float = 100.0

var health: float

var basic_attack_damage: int = 5
var basic_attack_target: Node3D = null
var basic_attack_hit := false
var current_basic_attack_projectile: Node3D = null


@export_category("Animação")
@export_range(0.0, 2.0, 0.01)
var animation_blend: float = 0.35

const DAMAGE_FONT: Font = preload("res://Fonts/Pix32.ttf")
var base_attack_scene = preload("res://Scenes/base_attack.tscn")
var fireball_scene = preload("res://Scenes/fireball_v1.tscn")
var energyball_scene = preload("res://Scenes/energy_ball.tscn")
var damage_buff_scene = preload("res://Scenes/damage_buff.tscn")
var healing_scene = preload("res://Scenes/healing_effect.tscn")
var thunderstorm_scene = preload("res://Scenes/thunderstorm.tscn")

var current_attack_target: Node3D = null

@onready var fireball_spawn = $FireballSpawn
@onready var animation_player = $AnimationPlayer
@onready var character_stats = $CharacterStats
@onready var level_up_effect = $LevelUpEffect

@onready var world_scroller = get_parent().get_node("World/WorldScroller")

var attacking := false
var action_locked := false
var skill_animation_finished = false
var attack_animation_playing := false
var is_running := false
var dead := false
var attack_id: int = 0
var basic_attack_lock := false

@export_category("Buff Settings")
var damage_buff_active: bool = false
var damage_buff_instance: Node3D = null

# Posição e rotação inicial do Mage
var initial_position: Vector3
var initial_rotation_y: float



func _ready():
	SaveManager.load_character(character_stats, character_stats.inventory)

	max_health = 100.0 + character_stats.get_max_health_bonus()
	health = max_health

	# Sempre inicia a fase com mana cheia
	character_stats.mana = character_stats.max_mana
	character_stats.mana_regen_timer = 0.0

	initial_position = global_position
	initial_rotation_y = rotation.y

	character_stats.attributes_changed.connect(_on_attributes_changed)
	character_stats.level_up_occurred.connect(play_level_up_effect)
	animation_player.animation_finished.connect(_on_animation_finished)




func use_skill(skill_id: String, target: Node3D):

	if not is_instance_valid(target):
		return

	if target.dying or target.health <= 0:
		return

	cancel_basic_attack()

	attack_id += 1
	var my_attack_id = attack_id

	action_locked = true

	if skill_id == "fireball" or skill_id == "energy_ball":
		current_attack_target = target
	else:
		current_attack_target = null

	look_at_target(target)

	attacking = true
	skill_animation_finished = false
	animation_player.speed_scale = 2.0

	match skill_id:

		"fireball":

			attack_animation_playing = true
			animation_player.play("mage/attack", animation_blend)

			await get_tree().create_timer(0.5).timeout

			if my_attack_id != attack_id:
				return

			if not is_instance_valid(target) or target.dying or target.health <= 0:
				attacking = false
				action_locked = false
				current_attack_target = null
				return

			var projectile = fireball_scene.instantiate()
			get_tree().current_scene.add_child(projectile)
			projectile.global_position = fireball_spawn.global_position
			projectile.target = target
			projectile.magic_bonus = character_stats.get_magic_bonus()
			projectile.character_stats = character_stats
			projectile.critical_chance = character_stats.get_critical_chance()
			projectile.critical_damage_multiplier = character_stats.get_critical_damage_multiplier()

			if damage_buff_active and is_instance_valid(damage_buff_instance):
				projectile.damage_multiplier = damage_buff_instance.damage_buff_multiplier * character_stats.get_magic_damage_multiplier()
			else:
				projectile.damage_multiplier = character_stats.get_magic_damage_multiplier()

			await projectile.finished

			if my_attack_id != attack_id:
				return

		"energy_ball":

			attack_animation_playing = true
			animation_player.play("mage/attack_2", animation_blend)

			await get_tree().create_timer(0.5).timeout

			if my_attack_id != attack_id:
				return

			if not is_instance_valid(target) or target.dying or target.health <= 0:
				attacking = false
				action_locked = false
				current_attack_target = null
				return

			var projectile = energyball_scene.instantiate()
			get_tree().current_scene.add_child(projectile)

			var spawn_position = get_target_position(target)
			spawn_position.y += 4.5
			spawn_position.x -= 3.0

			projectile.global_position = spawn_position
			projectile.target = target
			projectile.magic_bonus = character_stats.get_magic_bonus()
			projectile.character_stats = character_stats
			projectile.critical_chance = character_stats.get_critical_chance()
			projectile.critical_damage_multiplier = character_stats.CRITICAL_DAMAGE_MULTIPLIER

			if damage_buff_active and is_instance_valid(damage_buff_instance):
				projectile.damage_multiplier = damage_buff_instance.damage_buff_multiplier * character_stats.get_magic_damage_multiplier()
			else:
				projectile.damage_multiplier = character_stats.get_magic_damage_multiplier()

			await projectile.finished

			if my_attack_id != attack_id:
				return

		"damage_buff":

			print("SKILL -> BUFF DE DANO")

			animation_player.speed_scale = 1.0
			animation_player.play("mage/buff", animation_blend)

			await animation_player.animation_finished

			if my_attack_id != attack_id:
				return

			damage_buff_active = true
			damage_buff_instance = damage_buff_scene.instantiate()
			get_tree().current_scene.add_child(damage_buff_instance)
			damage_buff_instance.global_position = global_position

			print("BUFF CASTADO!")

			attacking = false
			action_locked = false

			var buff_duration = damage_buff_instance.duration
			await get_tree().create_timer(buff_duration).timeout

			damage_buff_active = false

			if is_instance_valid(damage_buff_instance):
				damage_buff_instance.queue_free()
				damage_buff_instance = null

			print("BUFF TERMINOU")
			current_attack_target = null
			return

		"heal":

			print("SKILL -> CURA")

			animation_player.speed_scale = 1.0
			animation_player.play("mage/heal", animation_blend)

			await animation_player.animation_finished

			if my_attack_id != attack_id:
				return

			if dead:
				return

			var healing_instance = healing_scene.instantiate()
			get_tree().current_scene.add_child(healing_instance)
			healing_instance.global_position = global_position

			var old_health = health
			health = minf(health + healing_instance.healing_amount, max_health)
			var healed_amount = health - old_health

			print("=== CURA APLICADA ===")
			print("Vida recuperada: ", healed_amount)
			print("Vida atual: ", health, "/", max_health)

			attacking = false
			action_locked = false
			current_attack_target = null

			await get_tree().create_timer(healing_instance.duration).timeout

			if is_instance_valid(healing_instance):
				healing_instance.queue_free()

			print("EFEITO DE CURA TERMINOU")
			return
			
		"thunderstorm":

			print("SKILL -> THUNDERSTORM")
			
			animation_player.speed_scale = 1.0
			animation_player.play("mage/attack_2", animation_blend)

			#await animation_player.animation_finished
			await get_tree().create_timer(1.2).timeout

			# Cria a tempestade e configura antes de entrar na árvore.
			var storm = thunderstorm_scene.instantiate()

			storm.center_target = target
			storm.magic_bonus = character_stats.get_magic_bonus()
			storm.character_stats = character_stats
			storm.critical_chance = character_stats.get_critical_chance()
			storm.critical_damage_multiplier = character_stats.CRITICAL_DAMAGE_MULTIPLIER

			if damage_buff_active and is_instance_valid(damage_buff_instance):
				storm.damage_multiplier = damage_buff_instance.damage_buff_multiplier * character_stats.get_magic_damage_multiplier()
			else:
				storm.damage_multiplier = character_stats.get_magic_damage_multiplier()

			get_tree().current_scene.add_child(storm)

			# Aguarda a conclusão dos raios.
			await storm.finished

			if my_attack_id != attack_id:
				return

		_:
			push_warning("ID de skill desconhecido no Mage: " + skill_id)
			attacking = false
			action_locked = false
			current_attack_target = null
			return

	attacking = false
	action_locked = false
	skill_animation_finished = true
	current_attack_target = null

func get_target_position(target: Node3D) -> Vector3:

	var magic_target = target.get_node_or_null("MagicTarget")

	if magic_target:
		return magic_target.global_position

	return target.global_position + Vector3(0, 1, 0)


func _on_animation_finished(anim_name):

	print("ANIMAÇÃO TERMINOU: ", anim_name)

	if dead and anim_name != "mage/die":
		return

	if anim_name == "mage/attack":

		animation_player.speed_scale = 1.0

		animation_player.play(
			"mage/idle2",
			animation_blend
		)

	elif anim_name == "mage/attack_2":

		animation_player.speed_scale = 1.0

		animation_player.play(
			"mage/idle2",
			animation_blend
		)

	elif anim_name == "mage/base_attack":
		print("base_attack terminou: ")
		animation_player.speed_scale = 1.0

		if not attacking:
			return

		animation_player.play(
			"mage/idle2",
			animation_blend
		)

	elif anim_name == "mage/buff":

		animation_player.speed_scale = 1.0

		animation_player.play(
			"mage/idle2",
			animation_blend
		)

	elif anim_name == "mage/die":

		attacking = false
		action_locked = false

		print("=== ANIMAÇÃO DE MORTE TERMINOU ===")

		animation_player.speed_scale = 1.0


func start_running():

	is_running = true
	attacking = false
	action_locked = false
	skill_animation_finished = false

	animation_player.speed_scale = 1.0

	animation_player.play(
		"mage/running",
		animation_blend
	)

func play_animation(_name):
	animation_player.play("mage/" + str(_name))

func start_combat():

	is_running = false
	attacking = false
	action_locked = false
	skill_animation_finished = false

	animation_player.speed_scale = 1.0

	animation_player.play(
		"player/idle2",
		animation_blend
	)


func look_at_target(target: Node3D):

	if not is_instance_valid(target):
		return

	var direction = target.global_position - global_position

	direction.y = 0.0

	rotation.y = atan2(
		direction.x,
		direction.z
	)


# ==========================================
# VOLTAR PARA A POSIÇÃO INICIAL
# ==========================================

func return_to_initial_position():

	global_position = initial_position
	rotation.y = initial_rotation_y

	#start_running()


func check_all_enemies_dead():

	print("=== VERIFICANDO INIMIGOS ===")

	var enemies = get_tree().get_nodes_in_group("enemies")

	print("Quantidade de inimigos: ", enemies.size())

	for enemy in enemies:

		if is_instance_valid(enemy) and not enemy.dying:

			print("Ainda existe inimigo vivo: ", enemy.name)
			return

	print("NÃO EXISTEM MAIS INIMIGOS VIVOS!")

	return_to_initial_position()


func take_damage(damage: float, damage_type: String = "physical"):
	if dead:
		return

	var final_damage := damage
	if is_instance_valid(character_stats):
		final_damage = character_stats.calculate_damage_after_defense(damage, damage_type)

	health -= final_damage

	# Apenas o flash visual de dano
	flash_hit()

	print(
		"Mage recebeu ",
		final_damage,
		" de dano. Vida: ",
		health,
		"/",
		max_health
	)

	show_damage(final_damage)

	if health <= 0:

		health = 0
		die()


func die():

	if dead:
		return

	dead = true

	print("=== Mago MORREU ===")

	# Para qualquer estado de combate
	attacking = false
	action_locked = false
	is_running = false
	skill_animation_finished = false
	attack_animation_playing = false

	# Invalida qualquer ação pendente
	attack_id += 1

	# Destrói projétil básico
	if is_instance_valid(current_basic_attack_projectile):

		current_basic_attack_projectile.queue_free()
		current_basic_attack_projectile = null

	# Para qualquer buff ativo
	damage_buff_active = false

	if is_instance_valid(damage_buff_instance):

		damage_buff_instance.queue_free()
		damage_buff_instance = null

	# Para a animação atual
	animation_player.speed_scale = 1.0

	# Executa a morte
	if animation_player.has_animation("mage/die"):

		animation_player.play(
			"mage/die",
			0.15
		)



func show_damage(damage: float):

	if not is_inside_tree():
		return

	var tree := get_tree()

	if tree == null:
		return

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

	var start_position: Vector3 = (
		global_position +
		Vector3(0, damage_height, 0)
	)

	label.global_position = start_position

	# Direção aleatória no plano horizontal.
	var direction := Vector3(
		randf_range(-1.0, 1.0),
		0.0,
		randf_range(-1.0, 1.0)
	).normalized()

	var horizontal_distance: float = randf_range(0.5, 1.0)
	var pop_height: float = randf_range(0.8, 1.4)

	var elapsed := 0.0

	while elapsed < damage_duration:

		if not is_instance_valid(self):
			return

		if not is_instance_valid(label):
			return

		if not is_inside_tree():
			label.queue_free()
			return

		elapsed += get_process_delta_time()

		var progress: float = clamp(
			elapsed / damage_duration,
			0.0,
			1.0
		)

		# Movimento horizontal contínuo.
		var horizontal_offset: Vector3 = (
			direction *
			horizontal_distance *
			progress
		)

		# Sobe até a metade e depois desce.
		# Sobe até o pico e desce suavemente em formato de sino.
		var vertical_offset: float = (
			sin(PI * progress) * pop_height
		)

		label.global_position = (
			start_position
			+ horizontal_offset
			+ Vector3(0.0, vertical_offset, 0.0)
		)

		await tree.process_frame

	if is_instance_valid(label):
		label.queue_free()



func _on_attributes_changed():
	var old_max_health = max_health

	max_health = 100.0 + character_stats.get_max_health_bonus()

	# Se a vida máxima aumentar, concede a diferença.
	if max_health > old_max_health:
		health += max_health - old_max_health

	# Se a vida máxima diminuir, limita a vida atual.
	health = clampf(health, 0.0, max_health)

	print("=== ATRIBUTOS ATUALIZADOS ===")
	print("Força total: ", character_stats.get_total_strength())
	print("Agilidade total: ", character_stats.get_total_agility())
	print("Inteligência total: ", character_stats.get_total_intelligence())
	print("Vitalidade total: ", character_stats.get_total_vitality())
	print("Vida máxima: ", max_health)
	print("Vida atual: ", health)



func flash_hit():

	var meshes = find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)

	for i in range(2):

		for mesh in meshes:

			if not is_instance_valid(mesh):
				continue

			# Não altera o shader do LevelUpEffect
			if mesh == level_up_effect or level_up_effect.is_ancestor_of(mesh):
				continue

			var material = mesh.get_active_material(0)

			if material == null:
				continue

			# Flash somente em materiais normais
			if material is ShaderMaterial:
				continue

			var flash_material = material.duplicate()

			flash_material.albedo_color = Color(
				1.0,
				0.03,
				0.03,
				1.0
			)

			flash_material.emission_enabled = true
			flash_material.emission = Color(
				1.0,
				0.0,
				0.0,
				1.0
			)

			flash_material.emission_energy_multiplier = 3.0

			mesh.material_override = flash_material

		await get_tree().create_timer(0.08).timeout

		for mesh in meshes:

			if not is_instance_valid(mesh):
				continue

			if mesh == level_up_effect or level_up_effect.is_ancestor_of(mesh):
				continue

			mesh.material_override = null

		await get_tree().create_timer(0.05).timeout


func play_level_up_effect():

	if not is_instance_valid(level_up_effect):
		return

	level_up_effect.visible = true

	await get_tree().create_timer(2.0).timeout

	level_up_effect.visible = false


func basic_attack(target: Node3D):

	if dead:
		return

	if action_locked:
		return

	if attacking:
		return

	if basic_attack_lock:
		return

	if not is_instance_valid(target):
		return

	if target.dying or target.health <= 0:
		return


	print(
		"⚔️ BASE ATTACK INICIADO: ",
		target.name,
		" | HEALTH: ",
		target.health,
		" | DYING: ",
		target.dying
	)


	# Novo ataque
	attack_id += 1

	var my_attack_id = attack_id

	current_attack_target = target
	basic_attack_lock = true
	action_locked = true
	attacking = true
	look_at_target(target)


	# ==========================================
	# ANIMAÇÃO
	# ==========================================

	var basic_attack_interval_multiplier: float = character_stats.get_basic_attack_interval_multiplier()
	var effective_animation_speed: float = animation_player_attack_base_duration / basic_attack_interval_multiplier
	animation_player.speed_scale = effective_animation_speed
	print(
		"base_attack INICIOU: 1")
	animation_player.play(
		"mage/base_attack",
		animation_blend
	)


	# Descobre a duração real da animação
	var attack_animation = animation_player.get_animation(
		"mage/base_attack"
	)

	var attack_duration = attack_animation.length / effective_animation_speed


	# ==========================================
	# TEMPO ATÉ LANÇAR O PROJÉTIL
	# ==========================================

	await get_tree().create_timer(
		attack_base_duration * basic_attack_interval_multiplier
	).timeout


	# Ataque foi cancelado?
	if my_attack_id != attack_id:
		return


	if not is_instance_valid(target):
		return


	if target.dying or target.health <= 0:
		return


	# ==========================================
	# CRIA PROJÉTIL
	# ==========================================

	var projectile = base_attack_scene.instantiate()

	get_tree().current_scene.add_child(projectile)

	current_basic_attack_projectile = projectile

	projectile.global_position = fireball_spawn.global_position
	projectile.target = target
	projectile.basic_attack_level = character_stats.basic_attack_level
	projectile.character_stats = character_stats
	print("base_attack TARGET ", target.name)
	projectile.magic_bonus = character_stats.get_magic_bonus()
	projectile.critical_chance = character_stats.get_critical_chance()
	projectile.critical_damage_multiplier = character_stats.CRITICAL_DAMAGE_MULTIPLIER
	
	if damage_buff_active and is_instance_valid(damage_buff_instance):
		projectile.damage_multiplier = damage_buff_instance.damage_buff_multiplier * character_stats.get_magic_damage_multiplier()
	else:
		projectile.damage_multiplier = character_stats.get_magic_damage_multiplier()


	await projectile.finished


	if current_basic_attack_projectile == projectile:
		current_basic_attack_projectile = null


	# Ataque foi cancelado?
	if my_attack_id != attack_id:
		return


	# ==========================================
	# AGUARDA O TEMPO MÍNIMO DO ATAQUE
	# ==========================================

	var remaining_time = attack_duration - (attack_base_duration * basic_attack_interval_multiplier)

	if remaining_time > 0.0:

		await get_tree().create_timer(
			remaining_time
		).timeout


	# Ataque foi cancelado durante a espera?
	if my_attack_id != attack_id:
		return


	# ==========================================
	# FINALIZA
	# ==========================================

	attacking = false
	basic_attack_lock = false
	action_locked = false

	current_attack_target = null
	basic_attack_target = null
	basic_attack_hit = false

	animation_player.speed_scale = 1.0



func cancel_attack_on_target(target: Node3D):

	if not is_instance_valid(target):
		return

	var is_current_target = current_attack_target == target

	var projectile_targets_enemy = false

	if is_instance_valid(current_basic_attack_projectile):
		if current_basic_attack_projectile.target == target:
			projectile_targets_enemy = true

	# Só cancela se o ataque atual ou o projétil
	# estiver relacionado ao inimigo que morreu.
	if not is_current_target and not projectile_targets_enemy:
		return

	print(
		"=== BASIC ATTACK CANCELADO === | ALVO: ",
		target.name
	)

	# Invalida os awaits pendentes do ataque anterior.
	attack_id += 1

	if is_instance_valid(current_basic_attack_projectile):
		if current_basic_attack_projectile.target == target:
			current_basic_attack_projectile.queue_free()
			current_basic_attack_projectile = null

	if is_current_target:

		current_attack_target = null
		basic_attack_target = null
		basic_attack_hit = false

		attacking = false
		basic_attack_lock = false
		action_locked = false

		if animation_player.current_animation == "mage/base_attack":

			animation_player.stop()
			animation_player.speed_scale = 1.0

			if not dead:
				animation_player.play(
					"mage/idle2",
					animation_blend
				)

	print("=== CANCELAMENTO CONCLUÍDO ===")

	attacking = false
	basic_attack_lock = false
	action_locked = false

	basic_attack_target = null
	current_attack_target = null
	basic_attack_hit = false


func cancel_basic_attack():

	if not basic_attack_lock:
		return

	print(
		"=== BASIC ATTACK CANCELADO ==="
	)

	attack_id += 1

	if is_instance_valid(current_basic_attack_projectile):

		current_basic_attack_projectile.queue_free()
		current_basic_attack_projectile = null


	if animation_player.current_animation == "mage/base_attack":

		animation_player.stop()

		animation_player.speed_scale = 1.0

		if not dead:

			animation_player.play(
				"mage/idle2",
				animation_blend
			)


	attacking = false
	basic_attack_lock = false

	basic_attack_target = null
	basic_attack_hit = false

	print(
		"=== BASIC ATTACK INVALIDADO ==="
	)
