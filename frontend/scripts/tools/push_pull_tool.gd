# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Push/Pull: dos clics — cara (``topo_id``) y punto en el plano de la cara para definir el vector.

signal status_message(text: String)
signal push_pull_completed(success: bool, message: String)

var _camera: Camera3D
var _project_view: Node3D
var _active: bool = false
var _step: int = 0
var _pending_guid: String = ""
var _pending_topo: String = ""
var _face_normal: Vector3 = Vector3.ZERO
var _anchor: Vector3 = Vector3.ZERO


func setup(camera: Camera3D, project_view: Node3D) -> void:
	_camera = camera
	_project_view = project_view


func activate() -> void:
	_active = true
	_step = 0
	_pending_guid = ""
	_pending_topo = ""
	Logger.info("Push/Pull: clic en una cara del muro; segundo clic define la extrusion.")


func deactivate() -> void:
	_active = false
	_step = 0
	_pending_guid = ""
	_pending_topo = ""


func is_active() -> bool:
	return _active


func handle_viewport_click(screen_pos: Vector2) -> void:
	if not _active or _camera == null:
		return
	if _step == 0:
		var hit: Dictionary = _project_view.pick_face_at_screen(_camera, screen_pos)
		if not bool(hit.get("ok", false)):
			push_pull_completed.emit(false, "Selecciona una cara de muro.")
			return
		_pending_guid = str(hit["guid"])
		_pending_topo = str(hit["topo_id"])
		_face_normal = hit["normal"] as Vector3
		_anchor = hit["position"] as Vector3
		_step = 1
		status_message.emit("Push/Pull: segundo clic para definir la profundidad.")
		return

	var vec: Vector3 = _extrusion_vector_from_click(screen_pos)
	if vec.length() < 1e-5:
		push_pull_completed.emit(false, "Vector de extrusion demasiado pequeno.")
		return
	await _submit(vec)


func _extrusion_vector_from_click(screen_pos: Vector2) -> Vector3:
	var O: Vector3 = _camera.project_ray_origin(screen_pos)
	var D: Vector3 = _camera.project_ray_normal(screen_pos)
	var denom: float = D.dot(_face_normal)
	if abs(denom) < 1e-7:
		return Vector3.ZERO
	var t: float = (_anchor - O).dot(_face_normal) / denom
	var pt: Vector3 = O + D * t
	var raw: Vector3 = pt - _anchor
	return _face_normal * raw.dot(_face_normal)


func _submit(vec: Vector3) -> void:
	var params: Dictionary = {
		"topo_id": _pending_topo,
		"vector": [vec.x, vec.y, vec.z],
	}
	var resp: Dictionary = await RpcClient.call_rpc("geom.extrude_face", params)
	if not is_inside_tree():
		return
	if not resp.get("ok"):
		var err: Variant = resp.get("error", {})
		push_pull_completed.emit(false, "geom.extrude_face: %s" % str(err))
		_step = 0
		return
	var result: Dictionary = resp["result"]
	var guid: String = str(result.get("guid", _pending_guid))
	var mesh_dict: Dictionary = result["mesh"] as Dictionary
	_project_view.replace_entity_mesh(guid, mesh_dict)
	_project_view.set_selection(guid)
	_active = false
	_step = 0
	push_pull_completed.emit(true, "Extrusion aplicada.")
