# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Push/Pull: dos clics — cara (``topo_id``) y segundo clic define la profundidad
## a lo largo de la **normal de la cara elegida en el primer clic** (coincide con el resaltado).

signal status_message(text: String)
signal push_pull_completed(success: bool, message: String)

const INVALID_PARAMS: int = -32602
const TOPO_ID_NOT_FOUND: int = -32002
const AxonLogger := preload("res://scripts/utils/axon_logger.gd")

var _camera: Camera3D
var _project_view: Node3D
var _active: bool = false
var _step: int = 0
var _editable_guid: String = ""
var _pending_guid: String = ""
var _pending_topo: String = ""
## Normal unitaria de extrusion (fijada en el primer clic; coincide con la cara resaltada).
var _extrusion_axis: Vector3 = Vector3.ZERO
var _anchor: Vector3 = Vector3.ZERO
## Normal del raycast al fijar la cara (orienta todos los triangulos con el mismo ``topo_id``).
var _lock_hit_normal: Vector3 = Vector3.ZERO


func setup(camera: Camera3D, project_view: Node3D) -> void:
	_camera = camera
	_project_view = project_view


func activate(editable_guid: String = "") -> void:
	_active = true
	_step = 0
	_editable_guid = editable_guid
	_pending_guid = ""
	_pending_topo = ""
	_extrusion_axis = Vector3.ZERO
	_lock_hit_normal = Vector3.ZERO
	_project_view.clear_face_hover()
	_project_view.clear_extrusion_preview()
	AxonLogger.info(
		"Push/Pull: pasa el raton sobre la cara; clic para fijarla; segundo clic = profundidad."
	)


func deactivate() -> void:
	_active = false
	_step = 0
	_editable_guid = ""
	_pending_guid = ""
	_pending_topo = ""
	_extrusion_axis = Vector3.ZERO
	_lock_hit_normal = Vector3.ZERO
	_project_view.clear_face_hover()
	_project_view.clear_extrusion_preview()


func is_active() -> bool:
	return _active


func is_selecting_face() -> bool:
	return _active and _step == 0


func has_pending_face() -> bool:
	return _active and _step == 1 and _pending_topo != ""


func is_awaiting_depth_click() -> bool:
	return _active and _step == 1


func apply_numeric_distance(distance_m: float) -> void:
	if not has_pending_face():
		push_pull_completed.emit(false, "Primero fija una cara para Push/Pull.")
		return
	if abs(distance_m) < 1e-5:
		push_pull_completed.emit(false, "Distancia de extrusion demasiado pequena.")
		return
	await _submit(_extrusion_axis * distance_m)


## Actualiza el volumen fantasma (cara logica desplazada) antes del segundo clic.
func update_extrusion_preview_at_screen(screen_pos: Vector2) -> void:
	if not is_awaiting_depth_click():
		return
	var vec: Vector3 = _extrusion_vector_from_click(screen_pos)
	_project_view.set_extrusion_preview(_pending_guid, _pending_topo, vec, _lock_hit_normal)


func handle_viewport_click(screen_pos: Vector2) -> void:
	if not _active or _camera == null:
		return
	if _step == 0:
		var hit: Dictionary = _project_view.pick_face_at_screen(_camera, screen_pos)
		if not bool(hit.get("ok", false)):
			_project_view.clear_face_hover()
			push_pull_completed.emit(false, "Selecciona una cara de muro.")
			return
		if _editable_guid != "" and str(hit["guid"]) != _editable_guid:
			_project_view.clear_face_hover()
			push_pull_completed.emit(false, "Edita solo el elemento activo.")
			return
		_pending_guid = str(hit["guid"])
		_pending_topo = str(hit["topo_id"])
		_extrusion_axis = (hit["normal"] as Vector3).normalized()
		if _extrusion_axis.length_squared() < 1e-12:
			_project_view.clear_face_hover()
			push_pull_completed.emit(false, "Normal de cara invalida.")
			return
		_anchor = hit["position"] as Vector3
		_lock_hit_normal = (hit["normal"] as Vector3).normalized()
		_project_view.lock_face_hover_from_hit(hit)
		_step = 1
		update_extrusion_preview_at_screen(screen_pos)
		status_message.emit("Push/Pull: mueve el raton para previsualizar; segundo clic confirma.")
		return

	var vec: Vector3 = _extrusion_vector_from_click(screen_pos)
	if vec.length() < 1e-5:
		_project_view.clear_extrusion_preview()
		push_pull_completed.emit(false, "Vector de extrusion demasiado pequeno.")
		return
	await _submit(vec)


func _extrusion_vector_from_click(screen_pos: Vector2) -> Vector3:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_pos)
	var denom: float = ray_direction.dot(_extrusion_axis)
	if abs(denom) < 1e-7:
		return Vector3.ZERO
	var t: float = (_anchor - ray_origin).dot(_extrusion_axis) / denom
	var pt: Vector3 = ray_origin + ray_direction * t
	var raw: Vector3 = pt - _anchor
	return _extrusion_axis * raw.dot(_extrusion_axis)


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
		_project_view.clear_face_hover()
		_project_view.clear_extrusion_preview()
		_step = 0
		_lock_hit_normal = Vector3.ZERO
		push_pull_completed.emit(false, _format_submit_error(err))
		return
	var result: Dictionary = resp["result"]
	var guid: String = str(result.get("guid", _pending_guid))
	var mesh_dict: Dictionary = result["mesh"] as Dictionary
	var topo_map: Dictionary = result.get("topo_map", {}) as Dictionary
	_project_view.clear_extrusion_preview()
	_project_view.replace_entity_mesh(guid, mesh_dict)
	if guid == _pending_guid:
		_project_view.remap_active_face_topo(_pending_topo, topo_map)
	_project_view.set_selection(guid)
	_active = false
	_step = 0
	_extrusion_axis = Vector3.ZERO
	_lock_hit_normal = Vector3.ZERO
	push_pull_completed.emit(true, "Extrusion aplicada.")


func _format_submit_error(err: Variant) -> String:
	if typeof(err) != TYPE_DICTIONARY:
		return "Push/Pull fallo: %s" % str(err)
	var error_dict: Dictionary = err
	var code: int = int(error_dict.get("code", 0))
	var message: String = str(error_dict.get("message", "error desconocido"))
	if code == TOPO_ID_NOT_FOUND:
		return "La cara seleccionada ya no existe. Vuelve a seleccionar una cara."
	if code == INVALID_PARAMS:
		return "Push/Pull no puede aplicar esa distancia: %s" % message
	return "Push/Pull fallo (%d): %s" % [code, message]
