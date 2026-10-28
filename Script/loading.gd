extends Control


@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar


var loading_path: String = ""


func _ready():

	loading_path = SceneLoader.target_scene_path

	if loading_path.is_empty():

		print("ERRO: Nenhuma cena foi definida para carregar.")
		return

	progress_bar.value = 0.0

	await get_tree().process_frame

	print("=== CARREGANDO CENA ===")
	print(loading_path)

	var scene = ResourceLoader.load(
		loading_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)

	if scene == null:

		print("ERRO: Não foi possível carregar a cena.")
		return

	progress_bar.value = 100.0

	await get_tree().process_frame

	get_tree().change_scene_to_packed(scene)
