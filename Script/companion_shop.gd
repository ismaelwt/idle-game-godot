
extends Control

@export_category("Companion")
@export var companion_id: String = "knight"
@export var companion_name: String = "Um Guerreiro como Companheiro"
@export var companion_price: int = 500

@onready var title_label: Label = $PanelContainer/Control/Control/VBoxContainer/TitleLabel
@onready var gold_label: Label = $PanelContainer/Control/Control/VBoxContainer/GoldLabel
@onready var description_label: Label = $PanelContainer/Control/Control/VBoxContainer/DescriptionLabel
@onready var status_label: Label = $PanelContainer/Control/Control/VBoxContainer/StatusLabel

@onready var buy_button: TextureButton = $PanelContainer/Control/Control/VBoxContainer/BuyButton
@onready var equip_button: TextureButton = $PanelContainer/Control/Control/VBoxContainer/EquipButton
@onready var unequip_button: TextureButton = $PanelContainer/Control/Control/VBoxContainer/UnequipButton
@onready var close_button: TextureButton = $PanelContainer/Control/CloseButton


func _ready() -> void:
	title_label.text = companion_name
	description_label.text = (
		"Um companheiro que poderá acompanhar seu herói."
		+ "\nPreço: %d ouro" % companion_price
	)

	buy_button.pressed.connect(_on_buy_pressed)
	equip_button.pressed.connect(_on_equip_pressed)
	unequip_button.pressed.connect(_on_unequip_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.companion_state_changed.connect(_refresh_ui)
	GameManager.global_state_changed.connect(_refresh_ui)

	_refresh_ui()


func _refresh_ui() -> void:
	gold_label.text = "Ouro: %d" % GameManager.gold

	var is_owned := GameManager.owns_companion(companion_id)
	var is_equipped := (
		GameManager.active_companion_id == companion_id
	)

	buy_button.visible = not is_owned
	buy_button.disabled = (
		is_owned
		or GameManager.gold < companion_price
		or companion_price <= 0
	)

	if is_owned:
		buy_button.disabled = true
	else:
		buy_button.disabled = false

	equip_button.visible = is_owned
	equip_button.disabled = is_equipped

	if is_equipped:
		equip_button.disabled = true
		equip_button.visible = false
		unequip_button.disabled = false
		unequip_button.visible = true
	else:
		equip_button.disabled = false
		equip_button.visible = true
		unequip_button.disabled = true
		unequip_button.visible = false

	if is_equipped:
		status_label.text = "Este companion está equipado."
	elif is_owned:
		status_label.text = "Companion adquirido. Você pode equipá-lo."
	elif GameManager.gold < companion_price:
		status_label.text = "Você ainda não tem ouro suficiente."
	else:
		status_label.text = "Disponível para compra."


func _on_buy_pressed() -> void:
	var success := GameManager.purchase_companion(
		companion_id,
		companion_price
	)

	if success:
		status_label.text = "Compra realizada com sucesso!"
	else:
		status_label.text = "Compra não realizada. Confira o ouro e o estado do companion."

	_refresh_ui()


func _on_equip_pressed() -> void:
	if GameManager.equip_companion(companion_id):
		status_label.text = "Companion equipado."
	else:
		status_label.text = "Não foi possível equipar o companion."

	_refresh_ui()


func _on_gold_changed(_new_amount: int) -> void:
	_refresh_ui()


func _on_close_pressed() -> void:
	hide()
	
func _on_unequip_pressed() -> void:
	if GameManager.unequip_companion():
		status_label.text = "Companion Desequipado."
	else:
		status_label.text = "Não foi possível desequipar o companion."

	_refresh_ui()
