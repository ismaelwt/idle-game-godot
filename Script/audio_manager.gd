extends Node
const SETTINGS_PATH := "user://audio_settings.cfg"
const SETTINGS_SECTION := "audio"

var music_player: AudioStreamPlayer
var music_tween: Tween

var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8


func _ready() -> void:
	_create_music_player()
	_load_settings()
	_apply_all_volumes()


func _create_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)


func play_music(stream: AudioStream, fade_duration: float = 0.0) -> void:
	if stream == null:
		push_warning("AudioManager: tentativa de tocar uma música nula.")
		return

	if music_player.stream == stream and music_player.playing:
		return

	if music_tween and music_tween.is_running():
		music_tween.kill()

	music_player.stream = stream

	if fade_duration <= 0.0:
		music_player.volume_db = 0.0
		music_player.play()
		return

	music_player.volume_db = -80.0
	music_player.play()

	music_tween = create_tween()
	music_tween.tween_property(
		music_player,
		"volume_db",
		0.0,
		fade_duration
	)


func stop_music(fade_duration: float = 0.0) -> void:
	if not is_instance_valid(music_player) or not music_player.playing:
		return

	if music_tween and music_tween.is_running():
		music_tween.kill()

	if fade_duration <= 0.0:
		music_player.stop()
		return

	music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", -80.0, fade_duration)
	music_tween.tween_callback(music_player.stop)


func play_sfx(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_sfx_3d(
	stream: AudioStream,
	world_position: Vector3,
	pitch_scale: float = 1.0
) -> void:
	if stream == null:
		return

	var audio_parent := get_tree().current_scene
	if audio_parent == null:
		audio_parent = self

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "SFX"
	player.pitch_scale = pitch_scale
	audio_parent.add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Master", master_volume)
	_save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	_save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	_save_settings()


func _apply_all_volumes() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)


func _apply_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("AudioManager: Audio Bus não encontrado: " + bus_name)
		return

	var volume_db := -80.0 if value <= 0.0 else linear_to_db(value)
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)

	if error != OK:
		return

	master_volume = clampf(
		float(config.get_value(SETTINGS_SECTION, "master_volume", master_volume)),
		0.0,
		1.0
	)
	music_volume = clampf(
		float(config.get_value(SETTINGS_SECTION, "music_volume", music_volume)),
		0.0,
		1.0
	)
	sfx_volume = clampf(
		float(config.get_value(SETTINGS_SECTION, "sfx_volume", sfx_volume)),
		0.0,
		1.0
	)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "master_volume", master_volume)
	config.set_value(SETTINGS_SECTION, "music_volume", music_volume)
	config.set_value(SETTINGS_SECTION, "sfx_volume", sfx_volume)

	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("AudioManager: não foi possível salvar as configurações de áudio.")
