# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends SceneTree

## Verifica que `ProjectView` pueda crear y actualizar entidades transitorias.

const ProjectViewScript := preload("res://scripts/viewport_3d/project_view.gd")


func _init() -> void:
	var view: Node3D = ProjectViewScript.new()
	root.add_child(view)

	var mesh_a: Dictionary = _make_box_mesh(1.0)
	var mesh_b: Dictionary = _make_box_mesh(2.0)

	view.upsert_transient_entity("sim_key", mesh_a)
	view.upsert_transient_entity("sim_key", mesh_b)
	view.remove_transient_entity("sim_key")

	print("project_view_transient_simulation: PASS")
	quit(0)


func _make_box_mesh(scale: float) -> Dictionary:
	return {
		"vertices": [
			0.0,
			0.0,
			0.0,
			scale,
			0.0,
			0.0,
			scale,
			scale,
			0.0,
			0.0,
			scale,
			0.0,
			0.0,
			0.0,
			scale,
			scale,
			0.0,
			scale,
			scale,
			scale,
			scale,
			0.0,
			scale,
			scale,
		],
		"indices": [
			0,
			1,
			2,
			0,
			2,
			3,
			4,
			6,
			5,
			4,
			7,
			6,
			0,
			4,
			5,
			0,
			5,
			1,
			1,
			5,
			6,
			1,
			6,
			2,
			2,
			6,
			7,
			2,
			7,
			3,
			3,
			7,
			4,
			3,
			4,
			0,
		],
		"normals": [
			-0.577,
			-0.577,
			-0.577,
			0.577,
			-0.577,
			-0.577,
			0.577,
			0.577,
			-0.577,
			-0.577,
			0.577,
			-0.577,
			-0.577,
			-0.577,
			0.577,
			0.577,
			-0.577,
			0.577,
			0.577,
			0.577,
			0.577,
			-0.577,
			0.577,
			0.577,
		],
	}
