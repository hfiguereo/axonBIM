# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Herramienta **crear muro**: encadena segmentos P1→P2 sobre el **plano horizontal del nivel base**
## (referencia **X/Y** en planta; cota vertical del forjado de trabajo = ``BASE_STOREY_ELEVATION_M``,
## nivel 00 hasta que exista sistema de plantas y **desfases**). En **vista 3D** el punto en planta se
## obtiene por intersección de rayo con ese plano (la cámara solo proyecta, no redefine el mundo). En
## **vista 2D OCC** la referencia inmediata es la geometría de la propia vista (suelo/forjado de ese
## datum), no el raycast de la cámara 3D. Inverencia tipo Revit/SketchUp (snap **X/Y**; **Alt+clic** =
## nuevo P1).

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

## Cota Z del forjado de nivel base (00). Sin sistema de niveles ni desfases aún; debe coincidir con
## la constante homónima en ``main_scene.gd``.
const BASE_STOREY_ELEVATION_M: float = 0.0

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


func _agent_debug_log(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	var payload: Dictionary = {
		"sessionId": "58a65c",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000.0,
	}
	var log_path: String = "/home/hector/AxonBIM/.cursor/debug-58a65c.log"
	var mode: FileAccess.ModeFlags = (
		FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE_READ
	)
	var f: FileAccess = FileAccess.open(log_path, mode)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.flush()
	f.close()


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
	_ensure_overlay()
	_redraw_overlay()
	Logger.info("Crear muro: activo. P1+P2 primera vez; luego continuan desde ultimo extremo.")
	draft_hint_changed.emit("Primera vez: P1 y P2. Siguientes: solo P2 desde el último clic. Alt+clic = nuevo origen.")
	hint_viewport_shortcuts()


func hint_viewport_shortcuts() -> void:
	pass


func deactivate() -> void:
	_active = false
	_has_first = false
	_preview_end_world = Vector3.ZERO
	_last_created_guid = ""
	_axis_lock = ""
	_destroy_overlay()
	draft_hint_changed.emit("")
	tool_cancelled.emit()


func is_active() -> bool:
	return _active


func has_first_point() -> bool:
	return _has_first


## Posición **X/Y** en planta del trazo en curso (cota Z = ``BASE_STOREY_ELEVATION_M``); para alzados
## OCC donde un eje no se ve, se reutiliza el otro eje de la cadena.
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
	_preview_end_world = _snap_second_point(_first_point, raw as Vector3)
	_redraw_overlay()
	_emit_length_hint()


## Movimiento con punto ya proyectado al plano z=0 (vista OCC 2D alineada al backend, no raycast 3D).
func handle_viewport_motion_world_floor(point_world_xy: Vector3) -> void:
	if not _active or not _has_first:
		return
	var raw := Vector3(point_world_xy.x, point_world_xy.y, BASE_STOREY_ELEVATION_M)
	_preview_end_world = _snap_second_point(_first_point, raw)
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
		Logger.info("Primer punto del muro (o nueva cadena): %s" % str(_first_point))
		return

	if alt_restart:
		_first_point = _snap_origin_axes(point_raw)
		_preview_end_world = _first_point
		_last_created_guid = ""
		_axis_lock = ""
		_redraw_overlay()
		draft_hint_changed.emit(
			"P1 reiniciado (Alt) en (%0.2f, %0.2f). Clic siguiente = P2." % [_first_point.x, _first_point.y]
		)
		Logger.info("Nuevo origen de trazo (Alt): %s" % str(_first_point))
		return

	var point: Vector3 = _snap_origin_axes(point_raw)
	var second_pt: Vector3 = _snap_second_point(_first_point, point)
	var seg_len: float = second_pt.distance_to(_first_point)
	if seg_len < MIN_SEGMENT_M:
		Logger.warn("Segmento demasiado corto; elige P2 más lejos.")
		draft_hint_changed.emit("Segmento corto. Ajusta P2 o usa Alt+clic para nuevo P1.")
		return

	var p1: Vector3 = _first_point
	var p2: Vector3 = second_pt
	_has_first = false
	_axis_lock = ""
	_preview_end_world = p2
	_redraw_overlay()
	await _submit_wall_and_chain(p1, p2, _last_created_guid)


## Clic con punto ya en plano horizontal (OCC 2D); evita ``project_ray`` del SubViewport 3D.
func handle_viewport_click_world_floor(point_world_xy: Vector3) -> void:
	if not _active:
		# #region agent log
		_agent_debug_log(
			"pre-fix-2",
			"H6",
			"create_wall_tool.gd:handle_viewport_click_world_floor",
			"ignored click: tool inactive",
			{"point_xy": [point_world_xy.x, point_world_xy.y]},
		)
		# #endregion
		return
	var point_raw: Vector3 = Vector3(point_world_xy.x, point_world_xy.y, BASE_STOREY_ELEVATION_M)
	var alt_restart: bool = Input.is_physical_key_pressed(KEY_ALT)
	# #region agent log
	_agent_debug_log(
		"pre-fix-2",
		"H6",
		"create_wall_tool.gd:handle_viewport_click_world_floor",
		"2d floor click received",
		{
			"has_first": _has_first,
			"alt_restart": alt_restart,
			"point_xy": [point_raw.x, point_raw.y],
			"last_guid": _last_created_guid,
		},
	)
	# #endregion
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
		Logger.info("Primer punto del muro (o nueva cadena): %s" % str(_first_point))
		return
	if alt_restart:
		_first_point = _snap_origin_axes(point_raw)
		_preview_end_world = _first_point
		_last_created_guid = ""
		_axis_lock = ""
		_redraw_overlay()
		draft_hint_changed.emit(
			"P1 reiniciado (Alt) en (%0.2f, %0.2f). Clic siguiente = P2." % [_first_point.x, _first_point.y]
		)
		Logger.info("Nuevo origen de trazo (Alt): %s" % str(_first_point))
		return
	var point: Vector3 = _snap_origin_axes(point_raw)
	var second_pt: Vector3 = _snap_second_point(_first_point, point)
	var seg_len: float = second_pt.distance_to(_first_point)
	if seg_len < MIN_SEGMENT_M:
		# #region agent log
		_agent_debug_log(
			"pre-fix-2",
			"H7",
			"create_wall_tool.gd:handle_viewport_click_world_floor",
			"segment rejected by min length",
			{
				"seg_len": seg_len,
				"min_len": MIN_SEGMENT_M,
				"p1": [_first_point.x, _first_point.y],
				"p2": [second_pt.x, second_pt.y],
			},
		)
		# #endregion
		Logger.warn("Segmento demasiado corto; elige P2 más lejos.")
		draft_hint_changed.emit("Segmento corto. Ajusta P2 o usa Alt+clic para nuevo P1.")
		return
	var p1: Vector3 = _first_point
	var p2: Vector3 = second_pt
	_has_first = false
	_axis_lock = ""
	_preview_end_world = p2
	_redraw_overlay()
	await _submit_wall_and_chain(p1, p2, _last_created_guid)


func _submit_wall_and_chain(p1: Vector3, p2: Vector3, join_with_guid: String) -> void:
	var ok: bool = await _submit_wall(p1, p2, join_with_guid)
	if not ok or not _active:
		_preview_end_world = Vector3.ZERO
		if _active:
			_redraw_overlay()
		return

	if _active:
		_first_point = Vector3(p2.x, p2.y, BASE_STOREY_ELEVATION_M)
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
	var t: float = (BASE_STOREY_ELEVATION_M - origin.z) / direction.z
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


func _submit_wall(p1: Vector3, p2: Vector3, join_with_guid: String) -> bool:
	var params: Dictionary = {
		"p1": {"x": p1.x, "y": p1.y, "z": BASE_STOREY_ELEVATION_M},
		"p2": {"x": p2.x, "y": p2.y, "z": BASE_STOREY_ELEVATION_M},
		"height": default_height,
		"thickness": default_thickness,
	}
	if join_with_guid != "":
		params["join_with_guid"] = join_with_guid
	# #region agent log
	_agent_debug_log(
		"pre-fix-2",
		"H8",
		"create_wall_tool.gd:_submit_wall",
		"submitting ifc.create_wall",
		{
			"p1": [p1.x, p1.y, p1.z],
			"p2": [p2.x, p2.y, p2.z],
			"height": default_height,
			"thickness": default_thickness,
			"join_with_guid": join_with_guid,
		},
	)
	# #endregion
	var resp: Dictionary = await RpcClient.call_rpc("ifc.create_wall", params)
	if not is_inside_tree():
		wall_submit_finished.emit()
		return false
	if not resp.get("ok"):
		# #region agent log
		_agent_debug_log(
			"pre-fix-2",
			"H8",
			"create_wall_tool.gd:_submit_wall",
			"ifc.create_wall failed",
			{"error": str(resp.get("error", {}))},
		)
		# #endregion
		Logger.error("create_wall fallo: %s" % str(resp.get("error")))
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
	# #region agent log
	_agent_debug_log(
		"pre-fix-2",
		"H8",
		"create_wall_tool.gd:_submit_wall",
		"ifc.create_wall ok",
		{"guid": guid, "workspace_half_xy": [half_xy.x, half_xy.y]},
	)
	# #endregion
	Logger.info("Muro creado: %s" % guid)
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
