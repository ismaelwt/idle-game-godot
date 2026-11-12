
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

# IDs dos companions equipados. O limite total continua sendo três heróis.
var equipped_companion_ids: Array[String] = []
# Compatibilidade com sistemas que esperam um único companion.
var active_companion_id: String:
	get:
		return equipped_companion_ids[0] if not equipped_companion_ids.is_empty() else ""
	set(value):
		equipped_companion_ids = []
		var normalized := str(value).strip_edges().to_lower()
		if not normalized.is_empty():
			equipped_companion_ids.append(normalized)

var _is_initializing: bool = true


func _ready() -> void:
	if has_node("/root/SaveManager"):
		var global_data: Dictionary = SaveManager.load_global_data()
		load_global_components(global_data)

	_is_initializing = false
	Log.d("GameManager: ouro global carregado: ", gold)


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

	Log.d("GameManager: +", amount, " ouro | Total: ", gold)
	return gold


func spend_gold(amount: int, persist: bool = true) -> bool:
	if amount <= 0 or gold < amount:
		return false

	set_gold(gold - amount, persist)

	Log.d("GameManager: -", amount, " ouro | Total: ", gold)
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

	var saved_equipped = data.get("equipped_companion_ids", [])
	equipped_companion_ids = []
	if saved_equipped is Array and not saved_equipped.is_empty():
		for companion_id in saved_equipped:
			_add_loaded_companion(str(companion_id))
	else:
		_add_loaded_companion(str(data.get("active_companion_id", "")))
	while equipped_companion_ids.size() > _get_companion_limit():
		equipped_companion_ids.pop_back()

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
		"active_companion_id": active_companion_id,
		"equipped_companion_ids": equipped_companion_ids
	})


func _add_loaded_companion(companion_id: String) -> void:
	var normalized := companion_id.strip_edges().to_lower()
	if normalized.is_empty() or equipped_companion_ids.has(normalized):
		return
	if equipped_companion_ids.size() >= 2 or not owns_companion(normalized):
		return
	equipped_companion_ids.append(normalized)


func unlock_level(level: int, persist: bool = true) -> void:
	var new_level := maxi(1, level)

	if new_level <= unlocked_level:
		return

	unlocked_level = new_level

	global_state_changed.emit()

	Log.d("GameManager: fase desbloqueada: ", unlocked_level)

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
		Log.d("Companion já adquirido: ", companion_id)
		return false

	# Desconta o ouro sem salvar ainda.
	# A compra e o novo saldo serão salvos juntos.
	if not spend_gold(price, false):
		Log.d("Ouro insuficiente para comprar: ", companion_id)
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

	Log.d(
		"COMPANION COMPRADO: ",
		companion_id,
		" | Preço: ",
		price,
		" | Ouro restante: ",
		gold
	)

	return true


func equip_companion(companion_id: String) -> bool:
	var normalized := companion_id.strip_edges().to_lower()
	if not owns_companion(normalized):
		Log.d("Não é possível equipar companion não adquirido: ", companion_id)
		return false

	if equipped_companion_ids.has(normalized):
		return true
	if equipped_companion_ids.size() >= _get_companion_limit():
		Log.d("Limite de companions equipados atingido.")
		return false

	equipped_companion_ids.append(normalized)

	if not _save_global_state():
		equipped_companion_ids.erase(normalized)
		return false

	companion_state_changed.emit()
	global_state_changed.emit()

	Log.d("COMPANION EQUIPADO: ", normalized)
	return true


func _get_companion_limit() -> int:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if is_instance_valid(scene):
		var manager := scene.find_child("PartyManager", true, false)
		if is_instance_valid(manager) and manager.get("max_party_size") != null:
			return maxi(0, int(manager.get("max_party_size")) - 1)
	return 2


func unequip_companion(companion_id: String = "") -> bool:
	var normalized := companion_id.strip_edges().to_lower()
	if normalized.is_empty():
		normalized = active_companion_id
	if normalized.is_empty() or not equipped_companion_ids.has(normalized):
		return true

	var previous_companions := equipped_companion_ids.duplicate()
	equipped_companion_ids.erase(normalized)

	if not _save_global_state():
		equipped_companion_ids = previous_companions
		return false

	companion_state_changed.emit()
	global_state_changed.emit()

	Log.d("COMPANION DESEQUIPADO: ", normalized)
	return true
