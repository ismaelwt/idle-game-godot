
extends MeshInstance3D

@export_category("Dunas")
@export_range(0.1, 5.0, 0.1) var dune_height: float = 1.5
@export_range(0.1, 1.0, 0.05) var dune_frequency: float = 0.35
@export_range(0.0, 1.5, 0.1) var dune_variation: float = 0.5


func _ready() -> void:
	generate_dunes()


func generate_dunes() -> void:
	var plane := mesh as PlaneMesh

	if plane == null:
		push_error("Ground precisa usar um PlaneMesh.")
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var width_segments: int = plane.subdivide_width + 1
	var depth_segments: int = plane.subdivide_depth + 1
	var half_width: float = plane.size.x * 0.5
	var half_depth: float = plane.size.y * 0.5

	for z in range(depth_segments):
		for x in range(width_segments):
			var p0 := create_vertex(x, z, width_segments, depth_segments, plane, half_width, half_depth)
			var p1 := create_vertex(x + 1, z, width_segments, depth_segments, plane, half_width, half_depth)
			var p2 := create_vertex(x, z + 1, width_segments, depth_segments, plane, half_width, half_depth)
			var p3 := create_vertex(x + 1, z + 1, width_segments, depth_segments, plane, half_width, half_depth)

			st.set_uv(Vector2(float(x) / width_segments, float(z) / depth_segments))
			st.add_vertex(p0)
			st.set_uv(Vector2(float(x) / width_segments, float(z + 1) / depth_segments))
			st.add_vertex(p2)
			st.set_uv(Vector2(float(x + 1) / width_segments, float(z) / depth_segments))
			st.add_vertex(p1)

			st.set_uv(Vector2(float(x + 1) / width_segments, float(z) / depth_segments))
			st.add_vertex(p1)
			st.set_uv(Vector2(float(x) / width_segments, float(z + 1) / depth_segments))
			st.add_vertex(p2)
			st.set_uv(Vector2(float(x + 1) / width_segments, float(z + 1) / depth_segments))
			st.add_vertex(p3)

	st.generate_normals()
	var generated_mesh := st.commit()

	if plane.material != null:
		generated_mesh.surface_set_material(0, plane.material)

	mesh = generated_mesh


func create_vertex(
	x: int,
	z: int,
	width_segments: int,
	depth_segments: int,
	plane: PlaneMesh,
	half_width: float,
	half_depth: float
) -> Vector3:
	var px: float = float(x) / width_segments * plane.size.x - half_width
	var pz: float = float(z) / depth_segments * plane.size.y - half_depth

	var wave: float = sin(pz * dune_frequency) * dune_height
	var variation: float = sin(px * dune_frequency * 0.6 + pz * 0.2) * dune_variation

	return Vector3(px, wave + variation, pz)
