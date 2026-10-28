
extends Node

## Estado global persistente do jogo.
## Autoload: GameManager

signal gold_changed(new_amount: int)
signal global_state_changed
signal companion_state_changed

var gold: int = 0
var unlocked_level: int = 1

var opened_chests: Dictionary = {}
var global_flags: Dictionary = {}

# Novos dados globais dos companions.
# Exemplo: {"wolf_companion": true}
var owned_companions: Dictionary = {}

# ID do companion atualmente equipado.
var active_companion_id: String = ""

var _is_initializing: bool = true


func _ready() -> void:
	if has_node("/root/SaveManager"):
		var global_data: Dictionary = SaveManager.load_global_data()
		load_global_components(global_data)

	_is_initializing = false
	print("GameManager: ouro global carregado: ", gold)


func set_gold(amount: int, persist: bool = true) -> void:
	var new_amount := maxi(0, amount)

	if gold == new_amount:
		return

	gold = new_amount
	gold_changed.emit(gold)
	global_state_changed.emit()

	if persist and not _is_initializing:
		_save_global_state()


func add_gold(amount: int, persist: bool = true) -> int:
	if amount <= 0:
		return gold

	set_gold(gold + amount, persist)

	print("GameManager: +", amount, " ouro | Total: ", gold)
	return gold


func spend_gold(amount: int, persist: bool = true) -> bool:
	if amount <= 0 or gold < amount:
		return false

	set_gold(gold - amount, persist)

	print("GameManager: -", amount, " ouro | Total: ", gold)
	return true


func has_enough_gold(amount: int) -> bool:
	return amount >= 0 and gold >= amount


func is_chest_opened(chest_id: String) -> bool:
	return bool(opened_chests.get(chest_id, false))


func mark_chest_opened(
	chest_id: String,
	persist: bool = true
) -> void:
	if chest_id.strip_edges().is_empty():
		push_warning("GameManager: chest_id vazio; estado do baú não salvo.")
		return

	if is_chest_opened(chest_id):
		return

	opened_chests[chest_id] = true
	global_state_changed.emit()

	if persist and not _is_initializing:
		_save_global_state()


func set_global_flag(
	flag_id: String,
	value: bool,
	persist: bool = true
) -> void:
	if flag_id.strip_edges().is_empty():
		push_warning("GameManager: flag_id vazio.")
		return

	if (
		global_flags.has(flag_id)
		and bool(global_flags[flag_id]) == value
	):
		return

	global_flags[flag_id] = value
	global_state_changed.emit()

	if persist and not _is_initializing:
		_save_global_state()


func get_global_flag(
	flag_id: String,
	default_value: bool = false
) -> bool:
	return bool(global_flags.get(flag_id, default_value))


func load_global_components(data: Dictionary) -> void:
	_is_initializing = true

	gold = maxi(0, int(data.get("gold", gold)))

	unlocked_level = maxi(
		1,
		int(data.get("unlocked_level", unlocked_level))
	)

	var saved_chests = data.get("opened_chests", {})
	opened_chests = (
		saved_chests.duplicate(true)
		if saved_chests is Dictionary
		else {}
	)

	var saved_flags = data.get("flags", {})
	global_flags = (
		saved_flags.duplicate(true)
		if saved_flags is Dictionary
		else {}
	)

	var saved_companions = data.get("owned_companions", {})
	owned_companions = (
		saved_companions.duplicate(true)
		if saved_companions is Dictionary
		else {}
	)

	active_companion_id = str(
		data.get("active_companion_id", "")
	)

	# Evita carregar um companion equipado que não consta
	# como adquirido no save.
	if (
		not active_companion_id.is_empty()
		and not owns_companion(active_companion_id)
	):
		active_companion_id = ""

	gold_changed.emit(gold)
	global_state_changed.emit()
	companion_state_changed.emit()

	_is_initializing = false


func _save_global_state() -> bool:
	if not has_node("/root/SaveManager"):
		push_warning("GameManager: SaveManager Autoload não encontrado.")
		return false

	return SaveManager.save_global_data({
		"gold": gold,
		"unlocked_level": unlocked_level,
		"opened_chests": opened_chests,
		"flags": global_flags,
		"owned_companions": owned_companions,
		"active_companion_id": active_companion_id
	})


func unlock_level(level: int, persist: bool = true) -> void:
	var new_level := maxi(1, level)

	if new_level <= unlocked_level:
		return

	unlocked_level = new_level

	global_state_changed.emit()

	print("GameManager: fase desbloqueada: ", unlocked_level)

	if persist and not _is_initializing:
		_save_global_state()


func get_unlocked_level() -> int:
	return unlocked_level


# ==================================================
# COMPANIONS
# ==================================================

func owns_companion(companion_id: String) -> bool:
	if companion_id.strip_edges().is_empty():
		return false

	return bool(owned_companions.get(companion_id, false))


func purchase_companion(
	companion_id: String,
	price: int
) -> bool:
	if companion_id.strip_edges().is_empty():
		push_warning("Companion: ID vazio.")
		return false

	if price <= 0:
		push_warning("Companion: o preço precisa ser maior que zero.")
		return false

	if owns_companion(companion_id):
		print("Companion já adquirido: ", companion_id)
		return false

	# Desconta o ouro sem salvar ainda.
	# A compra e o novo saldo serão salvos juntos.
	if not spend_gold(price, false):
		print("Ouro insuficiente para comprar: ", companion_id)
		return false

	owned_companions[companion_id] = true

	if not _save_global_state():
		# Se não foi possível salvar, desfaz a compra em memória.
		owned_companions.erase(companion_id)
		set_gold(gold + price, false)
		companion_state_changed.emit()
		return false

	companion_state_changed.emit()
	global_state_changed.emit()

	print(
		"COMPANION COMPRADO: ",
		companion_id,
		" | Preço: ",
		price,
		" | Ouro restante: ",
		gold
	)

	return true


func equip_companion(companion_id: String) -> bool:
	if not owns_companion(companion_id):
		print("Não é possível equipar companion não adquirido: ", companion_id)
		return false

	if active_companion_id == companion_id:
		return true

	var previous_companion := active_companion_id
	active_companion_id = companion_id

	if not _save_global_state():
		active_companion_id = previous_companion
		return false

	companion_state_changed.emit()
	global_state_changed.emit()

	print("COMPANION EQUIPADO: ", active_companion_id)
	return true


func unequip_companion() -> bool:
	if active_companion_id.is_empty():
		return true

	var previous_companion := active_companion_id
	active_companion_id = ""

	if not _save_global_state():
		active_companion_id = previous_companion
		return false

	companion_state_changed.emit()
	global_state_changed.emit()

	print("COMPANION DESEQUIPADO")
	return true
