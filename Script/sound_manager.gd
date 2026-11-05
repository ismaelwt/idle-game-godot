extends Control

@onready var master_slider: HSlider = $CenterContainer/Control/Panel/Panel/MarginContainer/VBoxContainer/HSlider
@onready var sfx_slider: HSlider = $CenterContainer/Control/Panel/Panel/MarginContainer/VBoxContainer/HSlider2
@onready var music_slider: HSlider = $CenterContainer/Control/Panel/Panel/MarginContainer/VBoxContainer/HSlider3
@onready var mute_button: TextureButton = $CenterContainer/Control/Panel/MuteButton
@onready var close_button: TextureButton = $CenterContainer/Control/Panel/CloseButton


func _ready() -> void:
	# Carrega os valores atuais sem disparar os sinais dos sliders.
	master_slider.set_value_no_signal(AudioManager.master_volume)
	sfx_slider.set_value_no_signal(AudioManager.sfx_volume)
	music_slider.set_value_no_signal(AudioManager.music_volume)

	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	mute_button.pressed.connect(_on_mute_button_pressed)
	close_button.pressed.connect(hide)


func _on_master_volume_changed(value: float) -> void:
	AudioManager.set_master_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)


func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value)


func _on_mute_button_pressed() -> void:
	AudioManager.set_muted(not AudioManager.is_muted)
