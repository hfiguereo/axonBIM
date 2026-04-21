# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Herramienta "crear muro": captura 2 clicks sobre el plano Z=0 del viewport
## y llama `ifc.create_wall` en el backend. Sprint 1.4.

signal wall_created(guid: String)
signal tool_cancelled
## Emitido al terminar ``_submit_wall`` (exito o error). Sirve para quitar
## la captura de clics del viewport sin depender de ``wall_created``.
signal wall_submit_finished

@export var default_height: float = 3.0
@export var default_thickness: float = 0.2

var _camera: Camera3D
var _project_view: Node3D
var _active: bool = false
var _first_point: Vector3 = Vector3.ZERO
var _has_first: bool = false


func setup(camera: Camera3D, project_view: Node3D) -> void:
	_camera = camera
	_project_view = project_view


func activate() -> void:
	_active = true
	_has_first = false
	Logger.info("Herramienta crear muro: activada. Clickea el primer punto.")


func deactivate() -> void:
	_active = false
	_has_first = false
	tool_cancelled.emit()


func is_active() -> bool:
	return _active


func handle_viewport_click(screen_pos: Vector2) -> void:
	if not _active or _camera == null:
		return

	var point: Variant = _project_ray_to_z_plane(screen_pos)
	if point == null:
		return

	if not _has_first:
		_first_point = point
		_has_first = true
		Logger.info("Primer punto del muro: %s" % str(_first_point))
		return

	var second_point: Vector3 = point
	_has_first = false
	_active = false
	await _submit_wall(_first_point, second_point)


func _project_ray_to_z_plane(screen_pos: Vector2) -> Variant:
	if _camera == null:
		return null
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var direction: Vector3 = _camera.project_ray_normal(screen_pos)
	if abs(direction.z) < 1e-6:
		return null
	var t: float = -origin.z / direction.z
	if t < 0.0:
		return null
	return origin + direction * t


func _submit_wall(p1: Vector3, p2: Vector3) -> void:
	var params: Dictionary = {
		"p1": {"x": p1.x, "y": p1.y, "z": 0.0},
		"p2": {"x": p2.x, "y": p2.y, "z": 0.0},
		"height": default_height,
		"thickness": default_thickness,
	}
	var resp: Dictionary = await RpcClient.call_rpc("ifc.create_wall", params)
	if not is_inside_tree():
		wall_submit_finished.emit()
		return
	if not resp.get("ok"):
		Logger.error("create_wall fallo: %s" % str(resp.get("error")))
		wall_submit_finished.emit()
		return

	var guid: String = resp["result"]["guid"]
	var mesh_dict: Dictionary = resp["result"]["mesh"]
	_project_view.add_entity(guid, mesh_dict)
	wall_created.emit(guid)
	Logger.info("Muro creado: %s" % guid)
	wall_submit_finished.emit()
