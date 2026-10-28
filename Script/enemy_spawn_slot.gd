
extends Resource
class_name EnemySpawnSlot

@export var enemy_scene: PackedScene

@export_range(0, 100, 1) var amount: int = 1
