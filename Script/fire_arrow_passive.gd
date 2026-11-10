extends Node

var icon: Texture2D = preload("res://icons/fire-arrow-skill.png")
var disabled_icon: Texture2D = preload("res://icons/fire-arrow-skill.png")


func get_description() -> String:
	return "Passiva: suas flechas têm 20% de chance de incendiar o inimigo,\n causando 3 de dano por segundo durante 3 segundos.\n Novos acertos renovam a duração da queimadura."
