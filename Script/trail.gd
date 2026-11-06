extends MeshInstance3D

@onready var trail_base: Marker3D = get_node("../TrailBase")
@onready var trail_tip: Marker3D = get_node("../TrailTip")

const MAX_SAMPLES := 5
const SAMPLE_INTERVAL := 0.025

var samples: Array[Dictionary] = []
var trail_active := false
var sample_timer := 0.0

var immediate_mesh: ImmediateMesh
var trail_material: StandardMaterial3D


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	visible = false

	immediate_mesh = ImmediateMesh.new()
	mesh = immediate_mesh

	trail_material = StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.albedo_color = Color(0.736, 0.743, 0.747, 0.79)
	#trail_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	material_override = trail_material


func _process(delta: float) -> void:
	if not trail_active:
		return

	sample_timer += delta

	if sample_timer >= SAMPLE_INTERVAL:
		sample_timer = 0.0
		capture_sample()
		update_trail()


func capture_sample() -> void:
	var sample: Dictionary = {
		"base": trail_base.global_position,
		"tip": trail_tip.global_position
	}

	samples.append(sample)

	while samples.size() > MAX_SAMPLES:
		samples.pop_front()


func update_trail() -> void:
	immediate_mesh.clear_surfaces()

	if samples.size() < 2:
		return

	immediate_mesh.surface_begin(
		Mesh.PRIMITIVE_TRIANGLE_STRIP,
		trail_material
	)

	for sample in samples:
		var base: Vector3 = to_local(sample["base"])
		var tip: Vector3 = to_local(sample["tip"])

		immediate_mesh.surface_add_vertex(base)
		immediate_mesh.surface_add_vertex(tip)

	immediate_mesh.surface_end()


func start_trail() -> void:
	samples.clear()
	sample_timer = 0.0
	trail_active = true
	visible = true

	capture_sample()


func stop_trail() -> void:
	trail_active = false
	visible = false
	samples.clear()
	immediate_mesh.clear_surfaces()
