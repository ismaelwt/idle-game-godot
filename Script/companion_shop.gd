
extends Control

@export_category("Companion")
var companion_id: String = ""
var companion_name: String = ""
@export var companion_price: int = 500

@onready var knight_avatar: TextureRect = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer/AvatarKnight
@onready var knight_title_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer/TitleLabel
@onready var knight_gold_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer/GoldLabel
@onready var knight_description_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer/DescriptionLabel
@onready var knight_status_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer/StatusLabel
@onready var knight_buy_button: TextureButton = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer/BuyButton
@onready var knight_equip_button: TextureButton = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer/EquipButton
@onready var knight_unequip_button: TextureButton = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer/UnequipButton


@onready var mage_avatar: TextureRect = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer2/AvatarMage
@onready var mage_title_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer2/TitleLabel
@onready var mage_gold_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer2/GoldLabel
@onready var mage_description_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer2/DescriptionLabel
@onready var mage_status_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer2/StatusLabel

@onready var mage_buy_button: TextureButton = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer2/BuyButton
@onready var mage_equip_button: TextureButton = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer2/EquipButton
@onready var mage_unequip_button: TextureButton = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer2/UnequipButton


@onready var archer_avatar: TextureRect = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer3/AvatarArcher
@onready var archer_title_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer3/TitleLabel
@onready var archer_gold_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer3/GoldLabel
@onready var archer_description_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer3/DescriptionLabel
@onready var archer_status_label: Label = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer3/StatusLabel

@onready var archer_buy_button: TextureButton = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer3/BuyButton
@onready var archer_equip_button: TextureButton = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer3/EquipButton
@onready var archer_unequip_button: TextureButton = $PanelContainer/Control/Control/HBoxContainer/VBoxContainer3/UnequipButton

@onready var close_button: TextureButton = $PanelContainer/Control/CloseButton


func _ready() -> void:
	_configure_companion_offer()
	
	knight_title_label.text = companion_name
	knight_description_label.text = (
		"Um companheiro que poderá acompanhar seu herói."
		+ "\nPreço: %d ouro" % companion_price
	)

	knight_buy_button.pressed.connect(_on_buy_pressed)
	knight_equip_button.pressed.connect(_on_equip_pressed)
	knight_unequip_button.pressed.connect(_on_unequip_pressed)
	
	mage_title_label.text = companion_name
	mage_description_label.text = (
		"Um companheiro que poderá acompanhar seu herói."
		+ "\nPreço: %d ouro" % companion_price
	)

	mage_buy_button.pressed.connect(_on_buy_pressed)
	mage_equip_button.pressed.connect(_on_equip_pressed)
	mage_unequip_button.pressed.connect(_on_unequip_pressed)
	
	
	close_button.pressed.connect(_on_close_pressed)
	
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.companion_state_changed.connect(_refresh_ui)
	GameManager.global_state_changed.connect(_refresh_ui)

	_refresh_ui()


func _configure_companion_offer() -> void:
	# O companion disponível é sempre o outro herói, diferente do principal.
	var selected_id := CharacterSelectionData.get_selected_character_id()

	match selected_id:
		"mage":
			companion_id = "knight"
			companion_name = "Cavaleiro Companheiro"
			knight_avatar.visible = true;
			mage_avatar.visible = false;
			return
		"knight":
			companion_id = "mage"
			companion_name = "Mago Companheiro"
			knight_avatar.visible = false;
			mage_avatar.visible = true;
			return
		_:
			# Fallback para saves/seleções desconhecidas: oferece o Cavaleiro.
			companion_id = "knight"
			companion_name = "Cavaleiro Companheiro"


func _refresh_ui() -> void:
	knight_gold_label.text = "Ouro: %d" % GameManager.gold

	var is_owned := GameManager.owns_companion(companion_id)
	var is_equipped := (
		GameManager.active_companion_id == companion_id
	)

	knight_buy_button.visible = not is_owned
	knight_buy_button.disabled = (
		is_owned
		or GameManager.gold < companion_price
		or companion_price <= 0
	)

	knight_equip_button.visible = is_owned
	knight_equip_button.disabled = is_equipped

	if is_equipped:
		knight_equip_button.disabled = true
		knight_equip_button.visible = false
		knight_unequip_button.disabled = false
		knight_unequip_button.visible = true
	else:
		knight_equip_button.disabled = false
		knight_equip_button.visible = true
		knight_unequip_button.disabled = true
		knight_unequip_button.visible = false

	if is_equipped:
		knight_status_label.text = "Este companion está equipado."
	elif is_owned:
		knight_status_label.text = "Companion adquirido. Você pode equipá-lo."
	elif GameManager.gold < companion_price:
		knight_status_label.text = "Você ainda não tem ouro suficiente."
	else:
		knight_status_label.text = "Disponível para compra."


func _on_buy_pressed() -> void:
	var success := GameManager.purchase_companion(
		companion_id,
		companion_price
	)

	if success:
		knight_status_label.text = "Compra realizada com sucesso!"
	else:
		knight_status_label.text = "Compra não realizada. Confira o ouro e o estado do companion."

	_refresh_ui()


func _on_equip_pressed() -> void:
	if GameManager.equip_companion(companion_id):
		knight_status_label.text = "Companion equipado."
	else:
		knight_status_label.text = "Não foi possível equipar o companion."

	_refresh_ui()


func _on_gold_changed(_new_amount: int) -> void:
	_refresh_ui()


func _on_close_pressed() -> void:
	hide()
	
func _on_unequip_pressed() -> void:
	if GameManager.unequip_companion():
		knight_status_label.text = "Companion Desequipado."
	else:
		knight_status_label.text = "Não foi possível desequipar o companion."

	_refresh_ui()
