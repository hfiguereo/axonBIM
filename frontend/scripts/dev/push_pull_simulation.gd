# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends SceneTree

## Smoke test de la herramienta Push/Pull sin UI interactiva.
##
## Simula: activar herramienta -> seleccionar cara -> arrastrar -> soltar.
## Sale con codigo 0 si emite preview + final con vector distinto de cero.

const PushPullTool := preload("res://scripts/tools/push_pull_tool.gd")

var _preview_seen: bool = false
var _final_seen: bool = false
var _final_vector: Vector3 = Vector3.ZERO
var _final_face_id: String = ""


func _init() -> void:
	var tool: Node = PushPullTool.new()
	root.add_child(tool)
	tool.drag_preview_changed.connect(_on_preview)
	tool.drag_finished.connect(_on_final)

	tool.activate()
	tool.handle_pointer_pressed(Vector2(100, 100))
	tool.handle_pointer_drag(Vector2(145, 80))
	tool.handle_pointer_released(Vector2(145, 80))
	tool.apply_topo_map({_final_face_id: "face.updated.001"})

	var ok: bool = (
		_preview_seen
		and _final_seen
		and _final_vector.length() > 0.0001
		and _final_face_id != ""
		and tool.current_face_id() == "face.updated.001"
	)
	if ok:
		print(
			"push_pull_simulation: PASS ",
			_final_face_id,
			" -> ",
			tool.current_face_id(),
			" ",
			_final_vector
		)
		quit(0)
	else:
		push_error("push_pull_simulation: FAIL")
		quit(1)


func _on_preview(vector: Vector3) -> void:
	_preview_seen = true
	_final_vector = vector


func _on_final(face_id: String, vector: Vector3) -> void:
	_final_seen = true
	_final_face_id = face_id
	_final_vector = vector
