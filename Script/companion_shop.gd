extends Control

@export_category("Preços dos Companions")
@export var mage_price: int = 500
@export var knight_price: int = 500
@export var archer_price: int = 500

@onready var knight_column: VBoxContainer = $PanelContainer/Control/HBoxContainer/VBoxContainer
@onready var knight_avatar: TextureRect = $PanelContainer/Control/HBoxContainer/VBoxContainer/AvatarKnight
@onready var knight_title_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer/TitleLabel
@onready var knight_gold_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer/GoldLabel
@onready var knight_description_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer/DescriptionLabel
@onready var knight_status_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer/StatusLabel
@onready var knight_buy_button: TextureButton = $PanelContainer/Control/HBoxContainer/VBoxContainer/BuyButton
@onready var knight_equip_button: TextureButton = $PanelContainer/Control/HBoxContainer/VBoxContainer/EquipButton
@onready var knight_unequip_button: TextureButton = $PanelContainer/Control/HBoxContainer/VBoxContainer/UnequipButton

@onready var mage_column: VBoxContainer = $PanelContainer/Control/HBoxContainer/VBoxContainer2
@onready var mage_avatar: TextureRect = $PanelContainer/Control/HBoxContainer/VBoxContainer2/AvatarMage
@onready var mage_title_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer2/TitleLabel
@onready var mage_gold_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer2/GoldLabel
@onready var mage_description_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer2/DescriptionLabel
@onready var mage_status_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer2/StatusLabel
@onready var mage_buy_button: TextureButton = $PanelContainer/Control/HBoxContainer/VBoxContainer2/BuyButton
@onready var mage_equip_button: TextureButton = $PanelContainer/Control/HBoxContainer/VBoxContainer2/EquipButton
@onready var mage_unequip_button: TextureButton = $PanelContainer/Control/HBoxContainer/VBoxContainer2/UnequipButton

@onready var archer_column: VBoxContainer = $PanelContainer/Control/HBoxContainer/VBoxContainer3
@onready var archer_avatar: TextureRect = $PanelContainer/Control/HBoxContainer/VBoxContainer3/AvatarArcher
@onready var archer_title_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer3/TitleLabel
@onready var archer_gold_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer3/GoldLabel
@onready var archer_description_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer3/DescriptionLabel
@onready var archer_status_label: Label = $PanelContainer/Control/HBoxContainer/VBoxContainer3/StatusLabel
@onready var archer_buy_button: TextureButton = $PanelContainer/Control/HBoxContainer/VBoxContainer3/BuyButton
@onready var archer_equip_button: TextureButton = $PanelContainer/Control/HBoxContainer/VBoxContainer3/EquipButton
@onready var archer_unequip_button: TextureButton = $PanelContainer/Control/HBoxContainer/VBoxContainer3/UnequipButton

@onready var close_button: TextureButton = $PanelContainer/Control/CloseButton


func _ready() -> void:
	_setup_hero_column("knight", "Cavaleiro", knight_title_label, knight_gold_label, knight_description_label, knight_status_label, knight_buy_button, knight_equip_button, knight_unequip_button, knight_price)
	_setup_hero_column("mage", "Mago", mage_title_label, mage_gold_label, mage_description_label, mage_status_label, mage_buy_button, mage_equip_button, mage_unequip_button, mage_price)
	_setup_hero_column("archer", "Arqueiro", archer_title_label, archer_gold_label, archer_description_label, archer_status_label, archer_buy_button, archer_equip_button, archer_unequip_button, archer_price)

	close_button.pressed.connect(_on_close_pressed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.companion_state_changed.connect(_refresh_ui)
	GameManager.global_state_changed.connect(_refresh_ui)
	_refresh_ui()


func _setup_hero_column(
	hero_id: String,
	display_name: String,
	title_label: Label,
	gold_label: Label,
	description_label: Label,
	status_label: Label,
	buy_button: TextureButton,
	equip_button: TextureButton,
	unequip_button: TextureButton,
	price: int
) -> void:
	title_label.text = display_name
	#description_label.text = "Um companheiro que poderá acompanhar seu herói.\nPreço: %d ouro" % price
	buy_button.pressed.connect(_on_buy_pressed.bind(hero_id))
	equip_button.pressed.connect(_on_equip_pressed.bind(hero_id))
	unequip_button.pressed.connect(_on_unequip_pressed.bind(hero_id))


func _refresh_ui() -> void:
	var main_hero_id: String = CharacterSelectionData.get_selected_character_id()
	_refresh_hero_column("knight", main_hero_id, knight_gold_label, knight_status_label, knight_buy_button, knight_equip_button, knight_unequip_button, knight_price)
	_refresh_hero_column("mage", main_hero_id, mage_gold_label, mage_status_label, mage_buy_button, mage_equip_button, mage_unequip_button, mage_price)
	_refresh_hero_column("archer", main_hero_id, archer_gold_label, archer_status_label, archer_buy_button, archer_equip_button, archer_unequip_button, archer_price)


func _refresh_hero_column(
	hero_id: String,
	main_hero_id: String,
	gold_label: Label,
	status_label: Label,
	buy_button: TextureButton,
	equip_button: TextureButton,
	unequip_button: TextureButton,
	price: int
) -> void:

	var is_main_hero: bool = hero_id == main_hero_id
	var is_owned: bool = GameManager.owns_companion(hero_id)
	var is_equipped: bool = GameManager.equipped_companion_ids.has(hero_id)

	if is_main_hero:
		buy_button.visible = false
		equip_button.visible = false
		unequip_button.visible = false
		gold_label.visible = false
		status_label.text = "Escolhido ✓"
		return

	buy_button.visible = not is_owned
	buy_button.disabled = GameManager.gold < price or price <= 0
	equip_button.visible = is_owned and not is_equipped
	var party_manager := get_tree().current_scene.find_child("PartyManager", true, false)
	var party_limit := int(party_manager.get("max_party_size")) if is_instance_valid(party_manager) else 3
	equip_button.disabled = GameManager.equipped_companion_ids.size() >= maxi(0, party_limit - 1)
	unequip_button.visible = is_owned and is_equipped
	unequip_button.disabled = false

	if is_equipped:
		status_label.text = "Equipado ✓"
	elif is_owned and equip_button.disabled:
		status_label.text = "Limite da equipe atingido"
	elif is_owned:
		status_label.text = "Adquirido ✓"
	elif price <= 0:
		status_label.text = "Preço indisponível."
	elif GameManager.gold < price:
		status_label.text = "Sem ouro"
	else:
		gold_label.text = "Ouro: %d" % GameManager.gold
		status_label.text = "Disponível"


func _on_buy_pressed(hero_id: String) -> void:
	var price: int = _get_hero_price(hero_id)
	if not GameManager.purchase_companion(hero_id, price):
		push_warning("Não foi possível comprar o companion: " + hero_id)
	_refresh_ui()


func _on_equip_pressed(hero_id: String) -> void:
	if not GameManager.equip_companion(hero_id):
		push_warning("Não foi possível equipar o companion: " + hero_id)
	_refresh_ui()


func _on_unequip_pressed(hero_id: String) -> void:
	if GameManager.equipped_companion_ids.has(hero_id):
		GameManager.unequip_companion(hero_id)
	_refresh_ui()


func _get_hero_price(hero_id: String) -> int:
	match hero_id:
		"mage":
			return mage_price
		"knight":
			return knight_price
		"archer":
			return archer_price
	return 0


func _on_gold_changed(_new_amount: int) -> void:
	_refresh_ui()


func _on_close_pressed() -> void:
	hide()
