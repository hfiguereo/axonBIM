# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Herramienta **crear muro**: encadena segmentos P1→P2 sobre el **plano horizontal del nivel base**
## (referencia **X/Y** en planta; cota Z del forjado = ``work_plane_elevation_m``, sincronizada con el
## nivel IFC activo desde la escena principal).
## En **vista 3D**, el punto en planta (X/Y) se obtiene por intersección de rayo con ese plano
## (la cámara solo proyecta, no redefine el mundo). En **vista 2D** (snapshot vectorial u ortográfica),
## la referencia es la geometría de la propia vista (suelo/forjado de ese datum), no el raycast 3D.
## Inverencia tipo Revit/SketchUp (snap **X/Y**; **Alt+clic** =
## nuevo P1). Al acercar el último **P2** al **primer vértice** del trazo (≈0,45 m), se acopla el cierre
## de habitación y el backend aplica el mismo tipo de ajuste de esquina que en la cadena (`join_end_guid`).

signal wall_created(guid: String, workspace_half_xy: Vector2)
signal tool_cancelled
signal wall_submit_finished
signal draft_hint_changed(hint: String)

const GUIDE_HALF_M: float = 72.0
const SNAP_AXIS_RATIO: float = 0.15
const SNAP_ORIGIN_M: float = 0.42
const MIN_SEGMENT_M: float = 0.05
const SNAP_LOCK_THRESHOLD_DEG: float = 14.0
const SNAP_UNLOCK_THRESHOLD_DEG: float = 24.0
const SNAP_MIN_LOCK_DISTANCE_M: float = 0.22
## Radio en planta para acoplar el **último** P2 al primer vértice del contorno (cierre de habitación).
const CLOSE_LOOP_SNAP_M: float = 0.45

## Cota Z por defecto antes de sincronizar RPC (debe coincidir con ``main_scene.gd``).
const BASE_STOREY_ELEVATION_M: float = 0.0

## Cota del forjado activo (nivel IFC seleccionado en Propiedades).
var work_plane_elevation_m: float = BASE_STOREY_ELEVATION_M

@export var default_height: float = 3.0
@export var default_thickness: float = 0.2

var _camera: Camera3D
var _project_view: Node3D
var _active: bool = false
var _first_point: Vector3 = Vector3.ZERO
var _has_first: bool = false
var _preview_end_world: Vector3 = Vector3.ZERO
var _overlay_mi: MeshInstance3D
var _immediate: ImmediateMesh
var _mat_axes: StandardMaterial3D
var _mat_preview: StandardMaterial3D
var _last_created_guid: String = ""
var _axis_lock: String = ""
var _loop_first_wall_guid: String = ""
var _loop_anchor_world: Vector3 = Vector3.ZERO


func _log_info(message: String) -> void:
	var logger: Node = get_node_or_null("/root/Logger")
	if logger != null and logger.has_method("info"):
		logger.call("info", message)
	else:
		print("[INFO ] ", message)


func _log_warn(message: String) -> void:
	var logger: Node = get_node_or_null("/root/Logger")
	if logger != null and logger.has_method("warn"):
		logger.call("warn", message)
	else:
		push_warning(message)


func _log_error(message: String) -> void:
	var logger: Node = get_node_or_null("/root/Logger")
	if logger != null and logger.has_method("error"):
		logger.call("error", message)
	else:
		push_error(message)


func setup(camera: Camera3D, project_view: Node3D) -> void:
	_camera = camera
	_project_view = project_view
	_mat_axes = _make_line_material(Color(0.95, 0.82, 0.18, 0.85))
	_mat_preview = _make_line_material(Color(0.25, 0.88, 1.0, 0.92))


func activate() -> void:
	_active = true
	_has_first = false
	_preview_end_world = Vector3.ZERO
	_last_created_guid = ""
	_axis_lock = ""
	_loop_first_wall_guid = ""
	_loop_anchor_world = Vector3.ZERO
	_ensure_overlay()
	_redraw_overlay()
	_log_info("Crear muro: activo. P1+P2 primera vez; luego continuan desde ultimo extremo.")
	draft_hint_changed.emit("Primera vez: P1 y P2. Siguientes: solo P2 desde el último clic. Alt+clic = nuevo origen.")
	hint_viewport_shortcuts()


func set_work_plane_elevation_m(z: float) -> void:
	work_plane_elevation_m = z


func hint_viewport_shortcuts() -> void:
	pass


func deactivate() -> void:
	_active = false
	_has_first = false
	_preview_end_world = Vector3.ZERO
	_last_created_guid = ""
	_axis_lock = ""
	_loop_first_wall_guid = ""
	_loop_anchor_world = Vector3.ZERO
	_destroy_overlay()
	draft_hint_changed.emit("")
	tool_cancelled.emit()


func is_active() -> bool:
	return _active


func has_first_point() -> bool:
	return _has_first


## Posición **X/Y** en planta del trazo en curso (cota Z = ``work_plane_elevation_m``); para alzados
## donde un eje no se ve en pantalla, se reutiliza el otro eje de la cadena.
func get_chain_floor_reference_xy() -> Vector2:
	if _has_first:
		return Vector2(_first_point.x, _first_point.y)
	return Vector2.ZERO


## Vacía el trazo en curso sin desactivar la herramienta (p. ej. al borrar desde propiedades).
func reset_draft() -> void:
	if not _active:
		return
	_has_first = false
	_preview_end_world = Vector3.ZERO
	_last_created_guid = ""
	_axis_lock = ""
	_loop_first_wall_guid = ""
	_loop_anchor_world = Vector3.ZERO
	_ensure_overlay()
	_redraw_overlay()
	draft_hint_changed.emit(
		"Primera vez: P1 y P2. Siguientes: solo P2 desde el último clic. Alt+clic = nuevo origen."
	)


func notify_defaults_changed() -> void:
	if _has_first:
		_emit_length_hint()


func handle_viewport_motion(screen_pos: Vector2) -> void:
	if not _active or not _has_first or _camera == null:
		return
	var raw: Variant = _project_ray_to_z_plane(screen_pos)
	if raw == null:
		return
	var snapped: Vector3 = _snap_second_point(_first_point, raw as Vector3)
	_preview_end_world = _maybe_snap_loop_close_xy(snapped)
	_redraw_overlay()
	_emit_length_hint()


## Movimiento con punto ya proyectado al plano z=0 (vista 2D alineada al backend, no raycast 3D).
func handle_viewport_motion_world_floor(point_world_xy: Vector3) -> void:
	if not _active or not _has_first:
		return
	var raw := Vector3(point_world_xy.x, point_world_xy.y, work_plane_elevation_m)
	var snapped: Vector3 = _snap_second_point(_first_point, raw)
	_preview_end_world = _maybe_snap_loop_close_xy(snapped)
	_redraw_overlay()
	_emit_length_hint()


func handle_viewport_click(screen_pos: Vector2) -> void:
	if not _active or _camera == null:
		return

	var point_v: Variant = _project_ray_to_z_plane(screen_pos)
	if point_v == null:
		return
	var alt_restart: bool = Input.is_physical_key_pressed(KEY_ALT)
	var point_raw: Vector3 = point_v as Vector3

	if not _has_first:
		var point_start: Vector3 = _snap_origin_axes(point_raw)
		_first_point = point_start
		_has_first = true
		_axis_lock = ""
		_preview_end_world = point_start
		_redraw_overlay()
		draft_hint_changed.emit(
			"P1=(%.2f, %.2f). Clic P2 — eje XY respecto al P1; Alt+clic aquí fuerza nuevo P1 desde el clic."
			% [_first_point.x, _first_point.y]
		)
		_log_info("Primer punto del muro (o nueva cadena): %s" % str(_first_point))
		return

	if alt_restart:
		_first_point = _snap_origin_axes(point_raw)
		_preview_end_world = _first_point
		_last_created_guid = ""
		_axis_lock = ""
		_loop_first_wall_guid = ""
		_loop_anchor_world = Vector3.ZERO
		_redraw_overlay()
		draft_hint_changed.emit(
			"P1 reiniciado (Alt) en (%0.2f, %0.2f). Clic siguiente = P2." % [_first_point.x, _first_point.y]
		)
		_log_info("Nuevo origen de trazo (Alt): %s" % str(_first_point))
		return

	var point: Vector3 = _snap_origin_axes(point_raw)
	var second_pt: Vector3 = _snap_second_point(_first_point, point)
	second_pt = _maybe_snap_loop_close_xy(second_pt)
	var join_end: String = ""
	if _is_loop_close_snap(second_pt):
		join_end = _loop_first_wall_guid
	var seg_len: float = second_pt.distance_to(_first_point)
	if seg_len < MIN_SEGMENT_M:
		_log_warn("Segmento demasiado corto; elige P2 más lejos.")
		draft_hint_changed.emit("Segmento corto. Ajusta P2 o usa Alt+clic para nuevo P1.")
		return

	var p1: Vector3 = _first_point
	var p2: Vector3 = second_pt
	_has_first = false
	_axis_lock = ""
	_preview_end_world = p2
	_redraw_overlay()
	await _submit_wall_and_chain(p1, p2, _last_created_guid, join_end)


## Clic con punto ya en plano horizontal (vista 2D); evita ``project_ray`` del SubViewport 3D.
func handle_viewport_click_world_floor(point_world_xy: Vector3) -> void:
	if not _active:
		return
	var point_raw: Vector3 = Vector3(point_world_xy.x, point_world_xy.y, work_plane_elevation_m)
	var alt_restart: bool = Input.is_physical_key_pressed(KEY_ALT)
	if not _has_first:
		var point_start: Vector3 = _snap_origin_axes(point_raw)
		_first_point = point_start
		_has_first = true
		_axis_lock = ""
		_preview_end_world = point_start
		_redraw_overlay()
		draft_hint_changed.emit(
			"P1=(%.2f, %.2f). Clic P2 — eje XY respecto al P1; Alt+clic aquí fuerza nuevo P1 desde el clic."
			% [_first_point.x, _first_point.y]
		)
		_log_info("Primer punto del muro (o nueva cadena): %s" % str(_first_point))
		return
	if alt_restart:
		_first_point = _snap_origin_axes(point_raw)
		_preview_end_world = _first_point
		_last_created_guid = ""
		_axis_lock = ""
		_loop_first_wall_guid = ""
		_loop_anchor_world = Vector3.ZERO
		_redraw_overlay()
		draft_hint_changed.emit(
			"P1 reiniciado (Alt) en (%0.2f, %0.2f). Clic siguiente = P2." % [_first_point.x, _first_point.y]
		)
		_log_info("Nuevo origen de trazo (Alt): %s" % str(_first_point))
		return
	var point: Vector3 = _snap_origin_axes(point_raw)
	var second_pt: Vector3 = _snap_second_point(_first_point, point)
	second_pt = _maybe_snap_loop_close_xy(second_pt)
	var join_end: String = ""
	if _is_loop_close_snap(second_pt):
		join_end = _loop_first_wall_guid
	var seg_len: float = second_pt.distance_to(_first_point)
	if seg_len < MIN_SEGMENT_M:
		_log_warn("Segmento demasiado corto; elige P2 más lejos.")
		draft_hint_changed.emit("Segmento corto. Ajusta P2 o usa Alt+clic para nuevo P1.")
		return
	var p1: Vector3 = _first_point
	var p2: Vector3 = second_pt
	_has_first = false
	_axis_lock = ""
	_preview_end_world = p2
	_redraw_overlay()
	await _submit_wall_and_chain(p1, p2, _last_created_guid, join_end)


func _submit_wall_and_chain(p1: Vector3, p2: Vector3, join_with_guid: String, join_end_guid: String) -> void:
	var was_establishing_loop: bool = _loop_first_wall_guid.is_empty()
	var ok: bool = await _submit_wall(p1, p2, join_with_guid, join_end_guid)
	if not ok or not _active:
		_preview_end_world = Vector3.ZERO
		if _active:
			_redraw_overlay()
		return

	if _active:
		if join_end_guid != "":
			_loop_first_wall_guid = ""
			_loop_anchor_world = Vector3.ZERO
		elif was_establishing_loop:
			_loop_first_wall_guid = _last_created_guid
			_loop_anchor_world = Vector3(p1.x, p1.y, work_plane_elevation_m)
		_first_point = Vector3(p2.x, p2.y, work_plane_elevation_m)
		_has_first = true
		_axis_lock = ""
		_preview_end_world = _first_point
		_redraw_overlay()
		_emit_length_hint()
		draft_hint_changed.emit(
			"Último clic (fin de muro) = P1 del siguiente segmento — mueve y clic P2, o Alt+clic nuevo P1."
		)


func _project_ray_to_z_plane(screen_pos: Vector2) -> Variant:
	if _camera == null:
		return null
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var direction: Vector3 = _camera.project_ray_normal(screen_pos)
	if abs(direction.z) < 1e-6:
		return null
	var t: float = (work_plane_elevation_m - origin.z) / direction.z
	if t < 0.0:
		return null
	return origin + direction * t


func _snap_origin_axes(p: Vector3) -> Vector3:
	var o := p
	if abs(o.x) < SNAP_ORIGIN_M:
		o.x = 0.0
	if abs(o.y) < SNAP_ORIGIN_M:
		o.y = 0.0
	return o


func _maybe_snap_loop_close_xy(candidate: Vector3) -> Vector3:
	if _loop_first_wall_guid.is_empty():
		return candidate
	var anchor_xy := Vector2(_loop_anchor_world.x, _loop_anchor_world.y)
	var cand_xy := Vector2(candidate.x, candidate.y)
	if anchor_xy.distance_to(cand_xy) <= CLOSE_LOOP_SNAP_M:
		return Vector3(_loop_anchor_world.x, _loop_anchor_world.y, work_plane_elevation_m)
	return candidate


func _is_loop_close_snap(second_pt: Vector3) -> bool:
	if _loop_first_wall_guid.is_empty():
		return false
	var anchor_xy := Vector2(_loop_anchor_world.x, _loop_anchor_world.y)
	var p2_xy := Vector2(second_pt.x, second_pt.y)
	return anchor_xy.distance_to(p2_xy) < 1e-3


func _snap_second_point(from: Vector3, raw: Vector3) -> Vector3:
	var o: Vector3 = _snap_origin_axes(raw)
	var d := Vector2(o.x - from.x, o.y - from.y)
	var ax: float = abs(d.x)
	var ay: float = abs(d.y)
	if ax < 1e-8 and ay < 1e-8:
		return o
	var dist: float = d.length()
	var tan_lock: float = tan(deg_to_rad(SNAP_LOCK_THRESHOLD_DEG))
	var tan_unlock: float = tan(deg_to_rad(SNAP_UNLOCK_THRESHOLD_DEG))
	if _axis_lock == "x":
		if ay <= tan_unlock * max(ax, 1e-8):
			o.y = from.y
			return o
		_axis_lock = ""
	elif _axis_lock == "y":
		if ax <= tan_unlock * max(ay, 1e-8):
			o.x = from.x
			return o
		_axis_lock = ""
	if dist >= SNAP_MIN_LOCK_DISTANCE_M:
		if ay <= tan_lock * max(ax, 1e-8):
			_axis_lock = "x"
		elif ax <= tan_lock * max(ay, 1e-8):
			_axis_lock = "y"
		elif ay <= SNAP_AXIS_RATIO * ax:
			_axis_lock = "x"
		elif ax <= SNAP_AXIS_RATIO * ay:
			_axis_lock = "y"
	if _axis_lock == "x":
		o.y = from.y
	elif _axis_lock == "y":
		o.x = from.x
	return o


func _emit_length_hint() -> void:
	if not _has_first:
		return
	var L: float = _first_point.distance_to(_preview_end_world)
	var axis_hint: String = "libre"
	if _axis_lock == "x":
		axis_hint = "X"
	elif _axis_lock == "y":
		axis_hint = "Y"
	draft_hint_changed.emit(
		"Largo en planta L≈%.2f m | eje %s | Alt. %.2f m | Esp. %.2f m"
		% [L, axis_hint, default_height, default_thickness]
	)


func _submit_wall(p1: Vector3, p2: Vector3, join_with_guid: String, join_end_guid: String) -> bool:
	var params: Dictionary = {
		"p1": {"x": p1.x, "y": p1.y, "z": work_plane_elevation_m},
		"p2": {"x": p2.x, "y": p2.y, "z": work_plane_elevation_m},
		"height": default_height,
		"thickness": default_thickness,
	}
	if join_with_guid != "":
		params["join_with_guid"] = join_with_guid
	if join_end_guid != "":
		params["join_end_guid"] = join_end_guid
	var resp: Dictionary = await RpcClient.call_rpc("ifc.create_wall", params)
	if not is_inside_tree():
		wall_submit_finished.emit()
		return false
	if not resp.get("ok"):
		_log_error("create_wall fallo: %s" % str(resp.get("error")))
		wall_submit_finished.emit()
		draft_hint_changed.emit("Error RPC. Clic P1 de nuevo (o Alt+clic para origen).")
		return false

	var guid: String = resp["result"]["guid"]
	var mesh_dict: Dictionary = resp["result"]["mesh"]
	var half_xy := Vector2(50.0, 50.0)
	var ws: Variant = resp["result"].get("workspace_xy_half_m")
	if ws is Array and ws.size() >= 2:
		half_xy = Vector2(float(ws[0]), float(ws[1]))
	_project_view.add_entity(guid, mesh_dict)
	_last_created_guid = guid
	wall_created.emit(guid, half_xy)
	_log_info("Muro creado: %s" % guid)
	wall_submit_finished.emit()
	return true


func _ensure_overlay() -> void:
	if _overlay_mi != null:
		return
	_overlay_mi = MeshInstance3D.new()
	_overlay_mi.name = "WallDraftOverlay"
	_project_view.add_child(_overlay_mi)
	_immediate = ImmediateMesh.new()
	_overlay_mi.mesh = null
	_overlay_mi.visible = false


func _destroy_overlay() -> void:
	if _overlay_mi != null:
		_overlay_mi.mesh = null
		_overlay_mi.queue_free()
	_overlay_mi = null
	_immediate = null


func _redraw_overlay() -> void:
	if _overlay_mi == null or _immediate == null:
		return
	if not _has_first:
		_overlay_mi.mesh = null
		_overlay_mi.visible = false
		return
	_overlay_mi.mesh = _immediate
	_overlay_mi.visible = true
	var inv: Transform3D = _project_view.global_transform.affine_inverse()
	var p1l: Vector3 = inv * _first_point
	var p2l: Vector3 = inv * _preview_end_world
	var z_off: float = 0.003
	p1l.z = z_off
	p2l.z = z_off

	_immediate.clear_surfaces()
	_draw_line_surface(
		p1l + Vector3(-GUIDE_HALF_M, 0.0, 0.0), p1l + Vector3(GUIDE_HALF_M, 0.0, 0.0), _mat_axes
	)
	_draw_line_surface(p1l + Vector3(0.0, -GUIDE_HALF_M, 0.0), p1l + Vector3(0.0, GUIDE_HALF_M, 0.0), _mat_axes)
	if p1l.distance_to(p2l) > 1e-4:
		_draw_line_surface(p1l, p2l, _mat_preview)


func _draw_line_surface(a: Vector3, b: Vector3, mat: Material) -> void:
	_immediate.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	_immediate.surface_add_vertex(a)
	_immediate.surface_add_vertex(b)
	_immediate.surface_end()


func _make_line_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	return mat
