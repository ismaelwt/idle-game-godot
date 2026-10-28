extends MeshInstance3D


func _ready():

	print("=== GROUND CARREGADO ===")

	if mesh == null:
		print("ERRO: Mesh não encontrado")
		return

	for i in range(mesh.get_surface_count()):

		var material = get_surface_override_material(i)

		if material == null:
			material = mesh.surface_get_material(i)

		if material is StandardMaterial3D:

			var next_pass = material.next_pass

			print("SURFACE: ", i)
			print("MATERIAL: ", material)
			print("NEXT PASS: ", next_pass)

			if next_pass is ShaderMaterial:

				print(
					"GRASS: ",
					next_pass.get_shader_parameter("grass_texture")
				)

				print(
					"DIRT: ",
					next_pass.get_shader_parameter("dirt_texture")
				)

				# Força novamente o vínculo do Next Pass.
				material.next_pass = null
				material.next_pass = next_pass
