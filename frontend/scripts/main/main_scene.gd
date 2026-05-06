# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Escena raiz de AxonBIM (Fase 2 — UI cinta + Push/Pull + undo RPC).

const OrbitRig := preload("res://scripts/viewport_3d/orbit_camera_rig.gd")
const CreateWallTool := preload("res://scripts/tools/create_wall_tool.gd")
const PushPullTool := preload("res://scripts/tools/push_pull_tool.gd")

const UI_SHELL: Color = Color(0.055, 0.071, 0.096, 1.0)
const UI_PANEL: Color = Color(0.078, 0.102, 0.137, 1.0)
const UI_PANEL_ELEVATED: Color = Color(0.102, 0.133, 0.176, 1.0)
const UI_BUTTON: Color = Color(0.118, 0.157, 0.208, 1.0)
const UI_BUTTON_HOVER: Color = Color(0.150, 0.207, 0.278, 1.0)
const UI_BUTTON_PRESSED: Color = Color(0.070, 0.183, 0.255, 1.0)
const UI_ACCENT_BLUE: Color = Color(0.219, 0.741, 0.973, 1.0)
const UI_ACCENT_AMBER: Color = Color(0.961, 0.620, 0.043, 1.0)
const UI_BORDER: Color = Color(0.169, 0.227, 0.298, 1.0)
const UI_TEXT: Color = Color(0.898, 0.945, 1.0, 1.0)
const UI_MUTED: Color = Color(0.580, 0.647, 0.725, 1.0)
const VIEWPORT_PERSP_CLEAR_BG: Color = Color(0.11, 0.115, 0.138, 1.0)
const VIEWPORT_ORTHO_CLEAR_BG: Color = Color(0.13, 0.14, 0.165, 1.0)
const VIEWPORT_PERSP_AMBIENT_ENERGY: float = 0.48
const VIEWPORT_ORTHO_AMBIENT_ENERGY: float = 0.40
const UI_ACCENT_DANGER: Color = Color(0.93, 0.32, 0.26, 1.0)
const USE_OCC_2D_VIEWS: bool = true
const VIEW2D_STATE_LOADING: String = "loading"
const VIEW2D_STATE_READY: String = "ready"
const VIEW2D_STATE_ERROR: String = "error"
const VIEW2D_STATE_FALLBACK: String = "fallback"
const VIEW2D_MODE_AUTO: String = "auto"
const VIEW2D_MODE_VECTORIAL: String = "vectorial"
const VIEW2D_MODE_ORTHO: String = "ortho"
const DEFAULT_PLAN_CUT_M: float = 1.2
const DEFAULT_PLAN_BOTTOM_M: float = 0.0
const DEFAULT_PLAN_TOP_M: float = 3.0
const DEFAULT_PLAN_DEPTH_M: float = 1.2

## Cota del forjado de nivel base (00). Sin niveles ni desfases aún; trazado 2D OCC proyecta a **X/Y**
## sobre este datum — la cámara 3D no es la referencia geométrica del trazo en vista 2D.
## Debe coincidir con ``create_wall_tool.gd`` (misma constante).
const BASE_STOREY_ELEVATION_M: float = 0.0

## Familias / tipologías de muro (altura y espesor en m). El id es trazabilidad en RPC.
const WALL_FAMILIES: Array = [
	{"id": "M-EST-030-020", "label": "Muro estructural 3,0 m / 0,20 m", "h": 3.0, "t": 0.2},
	{"id": "M-TAB-030-010", "label": "Tabique 3,0 m / 0,10 m", "h": 3.0, "t": 0.1},
	{"id": "M-BAJ-027-015", "label": "Muro bajo 2,7 m / 0,15 m", "h": 2.7, "t": 0.15},
	{"id": "M-ALT-032-025", "label": "Muro alto 3,2 m / 0,25 m", "h": 3.2, "t": 0.25},
]

var _wall_tool: Node
var _push_pull_tool: Node
var _muros_tree_parent: TreeItem
var _wall_tree_items: Dictionary = {}  # guid -> TreeItem
var _edit_mode_guid: String = ""
var _trace_wall_height: float = 3.0
var _trace_wall_thickness: float = 0.2
var _typology_spin_suppress: bool = false

@onready var _ribbon_tabs: TabBar = $%RibbonTabs
@onready var _ribbon_tools_inicio: Control = $%RibbonToolsInicio
@onready var _ribbon_tools_placeholder: Control = $%RibbonToolsPlaceholder
@onready var _ping_button: Button = $%PingButton
@onready var _wall_button: Button = $%CreateWallButton
@onready var _push_pull_button: Button = $%PushPullButton
@onready var _save_button: Button = $%SaveButton
@onready var _export_2d_views_button: Button = $%Export2DViewsButton
@onready var _export_wall_dxf_button: Button = $%ExportWallDxfButton
@onready var _view2d_mode_button: Button = $%View2DModeButton
@onready var _status_label: Label = $%StatusLabel
@onready var _rtt_label: Label = $%RttLabel
@onready var _log_label: Label = $%LogLabel
@onready var _project_tree: Tree = $%ProjectTree
@onready var _add_view2d_button: Button = %AddView2DButton
@onready var _delete_view2d_button: Button = %DeleteView2DButton
@onready var _prop_guid_label: Label = $%PropGuidLabel
@onready var _prop_type_label: Label = $%PropTypeLabel
@onready var _prop_dims_label: Label = $%PropDimsLabel
@onready var _edit_mode_button: Button = $%EditModeButton
@onready var _push_pull_distance: SpinBox = $%PushPullDistanceSpin
@onready var _push_pull_apply_distance_button: Button = $%ApplyPushPullDistanceButton
@onready var _camera_rig: Node3D = %CameraRig
@onready var _camera: Camera3D = %Camera3D
@onready var _project_view: Node3D = %ProjectView
@onready var _viewport_container: SubViewportContainer = $%ViewportContainer
@onready var _subviewport: SubViewport = $%SubViewport
@onready var _view_tabs_bar: TabBar = %ViewTabsBar
@onready var _view_2d_placeholder: PanelContainer = %View2DPlaceholder
@onready var _view_2d_placeholder_title: Label = %View2DPlaceholderTitle
@onready var _view_2d_placeholder_hint: Label = %View2DPlaceholderHint
@onready var _view_2d_preview: Control = %View2DPreview
@onready var _world_environment: WorldEnvironment = %WorldEnvironment
@onready var _grid: MeshInstance3D = %Grid
@onready var _light: DirectionalLight3D = %Light
@onready var _wall_draft_hint: Label = %WallDraftHint
@onready var _wall_typology_title: Label = %WallTypologyTitle
@onready var _wall_typology_option: OptionButton = %WallTypologyOption
@onready var _wall_typology_dims: HBoxContainer = %WallTypologyDims
@onready var _wall_props_height_spin: SpinBox = %WallPropsHeightSpin
@onready var _wall_props_thickness_spin: SpinBox = %WallPropsThicknessSpin
@onready var _wall_apply_typology_button: Button = %WallApplyTypologyButton
@onready var _delete_wall_button: Button = %DeleteWallButton
@onready var _wall_trace_typology_hint: Label = %WallTraceTypologyHint
@onready var _workspace_main_split: HSplitContainer = $UI/Root/Workspace/MainSplit
@onready var _workspace_inner_split: HSplitContainer = $UI/Root/Workspace/MainSplit/InnerSplit
@onready var _workspace_hud: Label = %WorkspaceHud

var _workspace_xy_half_cached: Vector2 = Vector2(50.0, 50.0)
var _hud_ticks: int = 0
var _active_view_tab: int = 0
var _views2d_tree_parent: TreeItem
var _view2d_items: Dictionary = {}  # id -> TreeItem
var _view2d_defs: Dictionary = {}  # id -> {label, preset}
var _view2d_runtime_state: Dictionary = {}  # id -> {preset,label,state,scale_m_per_px}
var _next_view2d_idx: int = 1
var _occ_wall_snapshot_debounce: Timer
var _occ_wall_snapshot_pending_id: String = ""
var _view2d_render_mode: String = VIEW2D_MODE_AUTO
var _has_last_valid_occ_uv: bool = false
var _last_valid_occ_uv: Vector2 = Vector2.ZERO


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


func _ready() -> void:
	Logger.info("AxonBIM frontend iniciado (Fase 2 · UI cinta + acoples).")
	_log_label.text = (
		"Vista: 1-3 orto | 4 persp — ambos fondo plano sin horizonte artefacto | "
		+ "MMB orbita orto→persp | Mayus+MMB pan | rueda zoom | Inicio/R reset"
	)
	_apply_visual_polish()

	_camera_rig.viewport_projection_mode_changed.connect(_on_viewport_projection_mode_changed)

	_ribbon_tabs.set_tab_title(0, "Inicio")
	_ribbon_tabs.set_tab_title(1, "Insertar")
	_ribbon_tabs.set_tab_title(2, "Vista")
	_ribbon_tabs.tab_changed.connect(_on_ribbon_tab_changed)
	_on_ribbon_tab_changed(_ribbon_tabs.current_tab)

	_wall_tool = CreateWallTool.new()
	add_child(_wall_tool)
	_wall_tool.setup(_camera, _project_view)
	_wall_tool.wall_created.connect(_on_wall_created)
	_wall_tool.draft_hint_changed.connect(_on_wall_draft_hint)
	_populate_wall_typology_option()
	_wall_typology_option.item_selected.connect(_on_wall_typology_option_item_selected)
	_wall_props_height_spin.value_changed.connect(_on_wall_props_typology_spin_changed)
	_wall_props_thickness_spin.value_changed.connect(_on_wall_props_typology_spin_changed)
	_wall_apply_typology_button.pressed.connect(_on_wall_apply_typology_pressed)
	_delete_wall_button.pressed.connect(_on_delete_wall_pressed)
	_sync_trace_defaults_to_wall_tool()

	_push_pull_tool = PushPullTool.new()
	add_child(_push_pull_tool)
	_push_pull_tool.setup(_camera, _project_view)
	_push_pull_tool.status_message.connect(_on_push_pull_status)
	_push_pull_tool.push_pull_completed.connect(_on_push_pull_completed)

	RpcClient.connected.connect(_on_rpc_connected)
	RpcClient.disconnected.connect(_on_rpc_disconnected)
	_ping_button.pressed.connect(_on_ping_pressed)
	_wall_button.pressed.connect(_on_create_wall_pressed)
	_push_pull_button.pressed.connect(_on_push_pull_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_export_2d_views_button.pressed.connect(_on_export_2d_views_pressed)
	_export_wall_dxf_button.pressed.connect(_on_export_wall_dxf_pressed)
	_view2d_mode_button.pressed.connect(_on_view2d_mode_toggle_pressed)
	_view_tabs_bar.tab_changed.connect(_on_view_tabs_changed)
	_add_view2d_button.pressed.connect(_on_add_view2d_pressed)
	_delete_view2d_button.pressed.connect(_on_delete_view2d_pressed)
	_edit_mode_button.pressed.connect(_on_edit_mode_button_pressed)
	_push_pull_apply_distance_button.pressed.connect(_on_push_pull_apply_distance_pressed)
	_viewport_container.gui_input.connect(_on_viewport_container_gui_input)
	_project_tree.item_selected.connect(_on_project_tree_item_selected)

	var occ_debounce := Timer.new()
	occ_debounce.wait_time = 0.12
	occ_debounce.one_shot = true
	occ_debounce.timeout.connect(_on_occ_wall_snapshot_debounce_timeout)
	add_child(occ_debounce)
	_occ_wall_snapshot_debounce = occ_debounce

	_build_project_tree()
	_refresh_status()
	_refresh_properties_panel()
	call_deferred("_refresh_workspace_hud")
	_update_view2d_mode_button_text()
	_on_view_tabs_changed(_view_tabs_bar.current_tab)


func _physics_process(_delta: float) -> void:
	_hud_ticks += 1
	if _hud_ticks % 12 != 0:
		return
	_refresh_workspace_hud()


func _refresh_workspace_hud() -> void:
	if _workspace_hud == null:
		return
	var cam_hint := ""
	if is_instance_valid(_camera_rig) and _camera_rig.has_method("get_viewport_scale_hint_fragment"):
		cam_hint = str(_camera_rig.get_viewport_scale_hint_fragment())
	var occ_hint: String = ""
	if USE_OCC_2D_VIEWS and _active_view_tab != 0:
		var preset: String = _tab_to_preset(_active_view_tab)
		var id: String = _find_view2d_id_by_preset(preset)
		if id != "":
			var row: Dictionary = _view2d_runtime_state.get(id, {}) as Dictionary
			var vr: Dictionary = row.get("view_range", {}) as Dictionary
			var zoom: float = 1.0
			if _view_2d_preview.has_method("zoom_factor"):
				zoom = float(_view_2d_preview.call("zoom_factor"))
			occ_hint = (
				" | OCC2D x%.2f · corte %.2fm · top %.2fm · bottom %.2fm"
				% [
					zoom,
					float(vr.get("cut_plane_m", DEFAULT_PLAN_CUT_M)),
					float(vr.get("top_m", DEFAULT_PLAN_TOP_M)),
					float(vr.get("bottom_m", DEFAULT_PLAN_BOTTOM_M)),
				]
			)
	_workspace_hud.text = (
		"Espacio IFC planta ±X %.0f m · ±Y %.0f m (medias)   |   %s%s"
		% [_workspace_xy_half_cached.x, _workspace_xy_half_cached.y, cam_hint, occ_hint]
	)


## Con vista 2D OCC a pantalla completa, el 3D no se redibuja cada fotograma (menos lag).
func _apply_subviewport_render_policy() -> void:
	if _subviewport == null:
		return
	var modelado: bool = _active_view_tab == 0
	var occ_covers: bool = USE_OCC_2D_VIEWS and not modelado
	if occ_covers:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


func _schedule_occ_view2d_refresh_after_wall(view2d_id: String) -> void:
	if view2d_id == "" or _occ_wall_snapshot_debounce == null:
		return
	_occ_wall_snapshot_pending_id = view2d_id
	_occ_wall_snapshot_debounce.start()


func _on_occ_wall_snapshot_debounce_timeout() -> void:
	var id: String = _occ_wall_snapshot_pending_id
	_occ_wall_snapshot_pending_id = ""
	if id == "":
		return
	_render_view2d_for_id(id)


func _on_view_tabs_changed(tab: int) -> void:
	_active_view_tab = tab
	_has_last_valid_occ_uv = false
	var modelado: bool = tab == 0
	_apply_subviewport_render_policy()
	_workspace_hud.visible = true
	_view_2d_placeholder.visible = USE_OCC_2D_VIEWS and not modelado
	%NavGizmo.visible = not USE_OCC_2D_VIEWS or modelado
	var rig: OrbitRig = _camera_rig as OrbitRig
	if rig == null:
		return
	if modelado:
		if _view_2d_preview.has_method("clear_snapshot"):
			_view_2d_preview.call("clear_snapshot")
		if _view_2d_preview.has_method("reset_view_transform"):
			_view_2d_preview.call("reset_view_transform")
		rig.set_view_preset("persp")
		_log_label.text = "Vista activa: Modelado 3D (interactivo)."
		return
	var preset: String = _tab_to_preset(tab)
	if not USE_OCC_2D_VIEWS:
		rig.set_view_preset(preset)
		_auto_frame_current_view2d()
		_log_label.text = (
			"Vista 2D activa (%s): pan/zoom/selección habilitados."
			% _view_tabs_bar.get_tab_title(tab)
		)
		return
	# OCC activo: si no viene del browser, resolver por preset default.
	var chosen_id: String = _find_view2d_id_by_preset(preset)
	if chosen_id == "":
		rig.set_view_preset(preset)
		_auto_frame_current_view2d()
		_log_label.text = "Vista 2D sin OCC asociada; fallback ortográfico."
		return
	_render_view2d_for_id(chosen_id)


func _set_wall_trace_mode(enable: bool) -> void:
	if not USE_OCC_2D_VIEWS:
		return
	if _active_view_tab == 0:
		return
	if not enable:
		var preset: String = _tab_to_preset(_active_view_tab)
		var id: String = _find_view2d_id_by_preset(preset)
		if id != "":
			_render_view2d_for_id(id)


func _render_view2d_for_id(id: String) -> void:
	if not _view2d_defs.has(id):
		# #region agent log
		_agent_debug_log(
			"pre-fix",
			"H2",
			"main_scene.gd:_render_view2d_for_id",
			"view id not found",
			{"id": id, "known_count": _view2d_defs.size()},
		)
		# #endregion
		return
	var d: Dictionary = _view2d_defs[id] as Dictionary
	var preset: String = str(d.get("preset", "top"))
	# #region agent log
	_agent_debug_log(
		"pre-fix",
		"H1",
		"main_scene.gd:_render_view2d_for_id",
		"render route selected",
		{"id": id, "preset": preset, "mode": _view2d_render_mode, "active_tab": _active_view_tab},
	)
	# #endregion
	if _view2d_render_mode == VIEW2D_MODE_ORTHO:
		_activate_legacy_ortho_view2d(preset, "Vista 2D: modo Modelo ortográfico activo.")
		return
	_render_occ_view2d_async(id)


func _activate_legacy_ortho_view2d(preset: String, message: String) -> void:
	var rig: OrbitRig = _camera_rig as OrbitRig
	if rig == null:
		return
	if _view_2d_preview.has_method("clear_snapshot"):
		_view_2d_preview.call("clear_snapshot")
	rig.set_view_preset(preset)
	_auto_frame_current_view2d()
	_log_label.text = message


func _on_view2d_mode_toggle_pressed() -> void:
	var prev_mode: String = _view2d_render_mode
	match _view2d_render_mode:
		VIEW2D_MODE_AUTO:
			_view2d_render_mode = VIEW2D_MODE_VECTORIAL
		VIEW2D_MODE_VECTORIAL:
			_view2d_render_mode = VIEW2D_MODE_ORTHO
		_:
			_view2d_render_mode = VIEW2D_MODE_AUTO
	# #region agent log
	_agent_debug_log(
		"pre-fix",
		"H1",
		"main_scene.gd:_on_view2d_mode_toggle_pressed",
		"2d mode toggled",
		{"prev_mode": prev_mode, "next_mode": _view2d_render_mode, "active_tab": _active_view_tab},
	)
	# #endregion
	_update_view2d_mode_button_text()
	if _active_view_tab == 0:
		return
	var preset: String = _tab_to_preset(_active_view_tab)
	var id: String = _find_view2d_id_by_preset(preset)
	if id != "":
		_render_view2d_for_id(id)


func _update_view2d_mode_button_text() -> void:
	match _view2d_render_mode:
		VIEW2D_MODE_VECTORIAL:
			_view2d_mode_button.text = "Modo 2D: Plano vectorial"
		VIEW2D_MODE_ORTHO:
			_view2d_mode_button.text = "Modo 2D: Modelo ortográfico"
		_:
			_view2d_mode_button.text = "Modo 2D: Auto (vectorial->orto)"


func _tab_to_preset(tab: int) -> String:
	match tab:
		1:
			return "top"
		2:
			return "front"
		3:
			return "right"
		_:
			return "persp"


## Convierte ``(u,v)`` del snapshot OCC a mundiales **X/Y** en el plano del nivel base (``BASE_STOREY_ELEVATION_M``).
func _occ_uv_to_floor_point_world(uv: Vector2) -> Vector3:
	var preset: String = _tab_to_preset(_active_view_tab)
	var ref: Vector2 = Vector2.ZERO
	if _wall_tool != null and _wall_tool.has_method("get_chain_floor_reference_xy"):
		ref = _wall_tool.call("get_chain_floor_reference_xy") as Vector2
	var zb: float = BASE_STOREY_ELEVATION_M
	match preset:
		"top":
			return Vector3(uv.x, uv.y, zb)
		"front":
			return Vector3(uv.x, ref.y, zb)
		"right":
			return Vector3(ref.x, uv.x, zb)
		_:
			return Vector3(uv.x, uv.y, zb)


func _find_view2d_id_by_preset(preset: String) -> String:
	for id in _view2d_defs.keys():
		var row: Dictionary = _view2d_defs[id] as Dictionary
		if str(row.get("preset", "")) == preset:
			return str(id)
	return ""


func _set_view2d_status(id: String, status: String, message: String) -> void:
	if not _view2d_runtime_state.has(id):
		return
	var row: Dictionary = _view2d_runtime_state[id] as Dictionary
	row["state"] = status
	_view2d_runtime_state[id] = row
	if _view2d_items.has(id):
		var item: TreeItem = _view2d_items[id] as TreeItem
		var label: String = str(row.get("label", item.get_text(0)))
		item.set_text(0, "%s [%s]" % [label, status])
	_view_2d_placeholder_hint.text = message


func _render_occ_view2d_async(id: String) -> void:
	if not _view2d_defs.has(id):
		return
	var d: Dictionary = _view2d_defs[id] as Dictionary
	var label: String = str(d.get("label", "Vista 2D"))
	var preset: String = str(d.get("preset", "top"))
	_view_2d_placeholder_title.text = "%s · Plano vectorial" % label
	_set_view2d_status(id, VIEW2D_STATE_LOADING, "Generando snapshot 2D analítico...")
	var params: Dictionary = {
		"view": preset,
		"width_px": max(256, int(_view_2d_preview.size.x)),
		"height_px": max(256, int(_view_2d_preview.size.y)),
		"margin_px": 24,
		"view_id": id,
		"projection_engine": "analytical",
	}
	if _view2d_runtime_state.has(id):
		var existing: Dictionary = _view2d_runtime_state[id] as Dictionary
		params["requested_scale_m_per_px"] = float(existing.get("scale_m_per_px", 1.0))
		params["view_range"] = existing.get("view_range", _default_view_range_for_preset(preset))
	var resp: Dictionary = await RpcClient.call_rpc("draw.ortho_snapshot", params, 30000)
	# #region agent log
	_agent_debug_log(
		"pre-fix",
		"H3",
		"main_scene.gd:_render_occ_view2d_async",
		"ortho snapshot response",
		{
			"id": id,
			"ok": bool(resp.get("ok", false)),
			"mode": _view2d_render_mode,
			"error": str(resp.get("error", {})),
		},
	)
	# #endregion
	if not is_inside_tree():
		return
	if not bool(resp.get("ok", false)):
		_set_view2d_status(id, VIEW2D_STATE_ERROR, "Snapshot 2D falló.")
		if _view2d_render_mode == VIEW2D_MODE_AUTO:
			_activate_legacy_ortho_view2d(
				preset,
				"Vista 2D vectorial falló; fallback a modelo ortográfico.",
			)
			return
		_log_label.text = "Vista 2D vectorial error: %s" % str(resp.get("error", {}))
		return
	var res: Dictionary = resp["result"] as Dictionary
	var lines: Array = res.get("lines_px", []) as Array
	if _view_2d_preview.has_method("set_snapshot"):
		_view_2d_preview.call("set_snapshot", lines)
	var bounds_uv: Array = res.get("world_bounds_uv", []) as Array
	if _view_2d_preview.has_method("set_occ_mapping"):
		_view_2d_preview.call(
			"set_occ_mapping",
			bounds_uv,
			int(res.get("width_px", 0)),
			int(res.get("height_px", 0)),
			int(params.get("margin_px", 24)),
		)
	var scale_m_per_px: float = float(res.get("meters_per_px", 1.0))
	if _view2d_runtime_state.has(id):
		var row: Dictionary = _view2d_runtime_state[id] as Dictionary
		row["scale_m_per_px"] = scale_m_per_px
		row["preset"] = preset
		row["label"] = label
		if res.has("view_range"):
			row["view_range"] = res["view_range"]
		_view2d_runtime_state[id] = row
	if int(res.get("line_count", 0)) == 0 and _view2d_render_mode == VIEW2D_MODE_AUTO:
		# #region agent log
		_agent_debug_log(
			"pre-fix",
			"H4",
			"main_scene.gd:_render_occ_view2d_async",
			"fallback by empty line_count",
			{"id": id, "line_count": int(res.get("line_count", 0)), "mode": _view2d_render_mode},
		)
		# #endregion
		_set_view2d_status(id, VIEW2D_STATE_FALLBACK, "Snapshot vacío; usando modelo ortográfico.")
		_activate_legacy_ortho_view2d(
			preset,
			"Vista 2D vectorial sin líneas; fallback a modelo ortográfico.",
		)
		return
	_set_view2d_status(
		id,
		VIEW2D_STATE_READY,
		"Snapshot OCC listo (%d líneas) · escala aprox %.4f m/px"
		% [int(res.get("line_count", 0)), scale_m_per_px],
	)
	_log_label.text = "Vista 2D vectorial lista: %s" % label


func _auto_frame_current_view2d() -> void:
	var rig: OrbitRig = _camera_rig as OrbitRig
	if rig == null:
		return
	var aabb: AABB = _project_view.get_scene_world_aabb()
	if aabb.size == Vector3.ZERO:
		return
	if rig.has_method("frame_ortho_aabb"):
		rig.frame_ortho_aabb(aabb)


func _apply_visual_polish() -> void:
	_apply_ui_polish()
	_apply_viewport_polish()


func _apply_ui_polish() -> void:
	_apply_panel_style($UI/Root/Ribbon/TitleBar, UI_SHELL, UI_BORDER, 0)
	_apply_panel_style($UI/Root/StatusBar, UI_PANEL_ELEVATED, UI_ACCENT_BLUE, 0)
	_apply_panel_style(
		$UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelSistema,
		UI_PANEL,
		UI_BORDER,
		10
	)
	_apply_panel_style(
		$UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelModelado,
		UI_PANEL,
		UI_BORDER,
		10
	)
	_apply_panel_style(
		$UI/Root/Ribbon/RibbonBody/RibbonStack/RibbonToolsInicio/PanelArchivo,
		UI_PANEL,
		UI_BORDER,
		10
	)
	_apply_panel_style($UI/Root/Workspace/MainSplit/LeftDock/LeftDockHeader, UI_PANEL, UI_BORDER, 8)
	_apply_panel_style(
		$UI/Root/Workspace/MainSplit/InnerSplit/RightDock/RightDockHeader, UI_PANEL, UI_BORDER, 8
	)
	_apply_panel_style(_project_tree, UI_PANEL, UI_BORDER, 8)
	_apply_panel_style(
		$UI/Root/Workspace/MainSplit/InnerSplit/RightDock/PropsScroll, UI_PANEL, UI_BORDER, 8
	)
	_apply_viewport_shell_no_inset_no_border()
	_apply_workspace_split_separator_cloak()
	_apply_button_style(_ping_button, UI_ACCENT_BLUE)
	_apply_button_style(_wall_button, UI_ACCENT_BLUE)
	_apply_button_style(_push_pull_button, UI_ACCENT_AMBER)
	_apply_button_style(_save_button, UI_ACCENT_BLUE)
	_apply_button_style(_export_2d_views_button, UI_ACCENT_BLUE)
	_apply_button_style(_export_wall_dxf_button, UI_ACCENT_BLUE)
	_apply_button_style(_view2d_mode_button, UI_ACCENT_BLUE)
	_apply_button_style(_add_view2d_button, UI_ACCENT_BLUE)
	_apply_button_style(_delete_view2d_button, UI_ACCENT_DANGER)
	_apply_panel_style(%ViewTabsHost, UI_PANEL_ELEVATED, UI_BORDER, 8)
	_apply_panel_style(_view_2d_placeholder, UI_PANEL_ELEVATED, UI_BORDER, 10)
	_apply_button_style(_edit_mode_button, UI_ACCENT_AMBER)
	_apply_button_style(_push_pull_apply_distance_button, UI_ACCENT_AMBER)
	_apply_button_style(_delete_wall_button, UI_ACCENT_DANGER)
	_apply_spinbox_style(_push_pull_distance)
	_apply_spinbox_style(_wall_props_height_spin)
	_apply_spinbox_style(_wall_props_thickness_spin)
	_style_label($UI/Root/Ribbon/TitleBar/AppTitle, UI_TEXT)
	_style_label(_status_label, UI_TEXT)
	_style_label(_rtt_label, UI_MUTED)
	_style_label(_log_label, UI_TEXT)
	_style_label($UI/Root/Workspace/MainSplit/LeftDock/LeftDockHeader/LeftDockTitle, UI_TEXT)
	_style_label(
		$UI/Root/Workspace/MainSplit/InnerSplit/RightDock/RightDockHeader/RightDockTitle, UI_TEXT
	)
	_style_project_tree()


func _apply_viewport_shell_no_inset_no_border() -> void:
	var shell: StyleBoxFlat = StyleBoxFlat.new()
	shell.bg_color = Color(0.017, 0.029, 0.048, 1.0)
	shell.border_width_left = 0
	shell.border_width_top = 0
	shell.border_width_right = 0
	shell.border_width_bottom = 0
	shell.corner_radius_top_left = 0
	shell.corner_radius_top_right = 0
	shell.corner_radius_bottom_right = 0
	shell.corner_radius_bottom_left = 0
	shell.content_margin_left = 0.0
	shell.content_margin_top = 0.0
	shell.content_margin_right = 0.0
	shell.content_margin_bottom = 0.0
	_viewport_container.add_theme_stylebox_override("panel", shell)


func _apply_workspace_split_separator_cloak() -> void:
	_workspace_inner_split.dragger_visibility = SplitContainer.DRAGGER_HIDDEN
	_workspace_main_split.dragger_visibility = SplitContainer.DRAGGER_HIDDEN


func _apply_environment_viewport_flat(is_perspective: bool) -> void:
	var env: Environment = _world_environment.environment
	if env == null:
		return
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = VIEWPORT_PERSP_CLEAR_BG if is_perspective else VIEWPORT_ORTHO_CLEAR_BG
	env.sky = null
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.54, 0.58, 1.0)
	env.ambient_light_energy = (
		VIEWPORT_PERSP_AMBIENT_ENERGY if is_perspective else VIEWPORT_ORTHO_AMBIENT_ENERGY
	)


func _on_viewport_projection_mode_changed(is_perspective: bool) -> void:
	_apply_environment_viewport_flat(is_perspective)


func _apply_viewport_polish() -> void:
	var env: Environment = _world_environment.environment
	if env == null:
		env = Environment.new()
		_world_environment.environment = env

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 5.5
	env.glow_enabled = false

	var rig_wants_persp: bool = (
		is_instance_valid(_camera_rig) and _camera_rig.has_method("is_perspective_preset")
		and bool(_camera_rig.is_perspective_preset())
	)
	_apply_environment_viewport_flat(rig_wants_persp)

	_light.light_color = Color(0.82, 0.90, 1.0, 1.0)
	_light.light_energy = 1.08
	_grid.material_override = _grid_material()
	_subviewport.msaa_3d = SubViewport.MSAA_4X
	var nav: PanelContainer = %NavGizmo as PanelContainer
	var nav_style := StyleBoxFlat.new()
	nav_style.bg_color = Color(0.10, 0.11, 0.13, 0.62)
	nav_style.border_color = Color(0.28, 0.30, 0.34, 0.5)
	nav_style.set_border_width_all(1)
	nav_style.set_corner_radius_all(6)
	nav.add_theme_stylebox_override("panel", nav_style)


func _apply_panel_style(control: Control, bg: Color, border: Color, radius: int) -> void:
	control.add_theme_stylebox_override("panel", _stylebox(bg, border, 1, radius))


func _apply_button_style(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _stylebox(UI_BUTTON, UI_BORDER, 1, 8))
	button.add_theme_stylebox_override("hover", _stylebox(UI_BUTTON_HOVER, accent, 1, 8))
	button.add_theme_stylebox_override("pressed", _stylebox(UI_BUTTON_PRESSED, accent, 2, 8))
	button.add_theme_stylebox_override("disabled", _stylebox(UI_PANEL, UI_BORDER, 1, 8))
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", UI_MUTED)
	button.add_theme_color_override("icon_normal_color", UI_TEXT)
	button.add_theme_color_override("icon_hover_color", accent)
	button.add_theme_color_override("icon_pressed_color", accent)
	button.add_theme_constant_override("h_separation", 8)


func _apply_spinbox_style(spinbox: SpinBox) -> void:
	spinbox.add_theme_color_override("font_color", UI_TEXT)
	spinbox.add_theme_color_override("font_uneditable_color", UI_MUTED)
	spinbox.add_theme_stylebox_override("normal", _stylebox(UI_BUTTON, UI_BORDER, 1, 8))
	spinbox.add_theme_stylebox_override("focus", _stylebox(UI_BUTTON_HOVER, UI_ACCENT_BLUE, 1, 8))


func _style_label(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)


func _style_project_tree() -> void:
	_project_tree.add_theme_color_override("font_color", UI_TEXT)
	_project_tree.add_theme_color_override("font_selected_color", Color.WHITE)
	_project_tree.add_theme_color_override("guide_color", Color(0.18, 0.25, 0.33, 1.0))
	_project_tree.add_theme_color_override("relationship_line_color", Color(0.18, 0.25, 0.33, 1.0))
	_project_tree.add_theme_color_override("drop_position_color", UI_ACCENT_BLUE)
	_project_tree.add_theme_stylebox_override(
		"selected", _stylebox(Color(0.072, 0.216, 0.306, 1.0), UI_ACCENT_BLUE, 1, 6)
	)


func _stylebox(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_right = radius
	box.corner_radius_bottom_left = radius
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


func _grid_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.40, 0.44, 0.26)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.38, 0.42, 1.0)
	mat.emission_energy_multiplier = 0.055
	mat.roughness = 1.0
	return mat


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and k.keycode == KEY_Z and k.ctrl_pressed and k.shift_pressed:
			_do_redo_async()
		elif k.pressed and k.keycode == KEY_Z and k.ctrl_pressed:
			_do_undo_async()
		elif k.pressed and k.keycode == KEY_DELETE and _delete_wall_shortcut_allowed():
			_on_delete_wall_pressed()
			get_viewport().set_input_as_handled()
		elif k.pressed and k.keycode == KEY_ESCAPE and _wall_tool.is_active():
			_cancel_wall_tool_with_esc()
			get_viewport().set_input_as_handled()
		elif k.pressed and k.keycode == KEY_ESCAPE and _is_edit_mode_active():
			_exit_edit_mode("Modo edición: cerrado")
		elif k.pressed and _active_view_tab != 0 and USE_OCC_2D_VIEWS:
			if k.keycode == KEY_PAGEUP:
				_adjust_active_view_cut(+0.1)
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_PAGEDOWN:
				_adjust_active_view_cut(-0.1)
				get_viewport().set_input_as_handled()


func _adjust_active_view_cut(delta_m: float) -> void:
	var preset: String = _tab_to_preset(_active_view_tab)
	var id: String = _find_view2d_id_by_preset(preset)
	if id == "":
		return
	if not _view2d_runtime_state.has(id):
		return
	var row: Dictionary = _view2d_runtime_state[id] as Dictionary
	var vr: Dictionary = row.get("view_range", _default_view_range_for_preset(preset)) as Dictionary
	var cut: float = float(vr.get("cut_plane_m", DEFAULT_PLAN_CUT_M))
	var bottom: float = float(vr.get("bottom_m", DEFAULT_PLAN_BOTTOM_M))
	var top: float = float(vr.get("top_m", DEFAULT_PLAN_TOP_M))
	cut = clampf(cut + delta_m, bottom, top)
	vr["cut_plane_m"] = cut
	row["view_range"] = vr
	_view2d_runtime_state[id] = row
	_render_view2d_for_id(id)
	_refresh_workspace_hud()
	_log_label.text = "Planta 2D OCC: plano de corte %.2f m (PgUp/PgDn)." % cut


func _do_undo_async() -> void:
	var resp: Dictionary = await RpcClient.call_rpc("history.undo", {})
	_apply_history_response(resp, "Undo")


func _do_redo_async() -> void:
	var resp: Dictionary = await RpcClient.call_rpc("history.redo", {})
	_apply_history_response(resp, "Redo")


func _apply_history_response(resp: Dictionary, label: String) -> void:
	if not is_inside_tree():
		return
	if not resp.get("ok"):
		_log_label.text = "%s: %s" % [label, str(resp.get("error"))]
		return
	var r: Dictionary = resp["result"] as Dictionary
	if not bool(r.get("applied", false)):
		_log_label.text = "%s: %s" % [label, str(r.get("reason", "nada"))]
		return
	var guid: String = str(r.get("guid", ""))
	var mesh_dict: Dictionary = r.get("mesh", {}) as Dictionary
	if guid != "" and not mesh_dict.is_empty():
		_project_view.replace_entity_mesh(guid, mesh_dict)
		_project_view.set_selection(guid)
		_refresh_properties_panel()
	_log_label.text = "%s aplicado." % label


func _on_push_pull_status(text: String) -> void:
	_log_label.text = text


func _on_push_pull_completed(success: bool, message: String) -> void:
	_log_label.text = message
	if success and message.begins_with("Extrusion"):
		_refresh_properties_panel()
		_sync_wall_defaults_from_selected_wall_if_possible()


func _on_ribbon_tab_changed(tab: int) -> void:
	var inicio: bool = tab == 0
	_ribbon_tools_inicio.visible = inicio
	_ribbon_tools_placeholder.visible = not inicio


func _build_project_tree() -> void:
	_project_tree.clear()
	_wall_tree_items.clear()
	_view2d_items.clear()
	_view2d_defs.clear()
	_view2d_runtime_state.clear()
	var hidden_root: TreeItem = _project_tree.create_item()
	var proyecto: TreeItem = _project_tree.create_item(hidden_root)
	proyecto.set_text(0, "Proyecto (sesión)")
	var vistas: TreeItem = _project_tree.create_item(proyecto)
	vistas.set_text(0, "Vistas")
	var v3d: TreeItem = _project_tree.create_item(vistas)
	v3d.set_text(0, "Vista 3D")
	v3d.set_metadata(0, "VIEW_3D")
	_views2d_tree_parent = _project_tree.create_item(vistas)
	_views2d_tree_parent.set_text(0, "Vistas 2D")
	_views2d_tree_parent.set_metadata(0, "CATEGORY_VIEWS2D")
	_register_view2d_tree_item("Planta", "top")
	_register_view2d_tree_item("Frente", "front")
	_register_view2d_tree_item("Derecha", "right")
	var ifc: TreeItem = _project_tree.create_item(proyecto)
	ifc.set_text(0, "IFC")
	_muros_tree_parent = _project_tree.create_item(ifc)
	_muros_tree_parent.set_text(0, "Muros")
	_muros_tree_parent.set_metadata(0, "CATEGORY_MUROS")


func _on_project_tree_item_selected() -> void:
	var item: TreeItem = _project_tree.get_selected()
	if item == null:
		return
	var md: Variant = item.get_metadata(0)
	if md is String and String(md) == "VIEW_3D":
		_view_tabs_bar.current_tab = 0
		_on_view_tabs_changed(0)
		_project_view.clear_selection()
		_refresh_properties_panel()
		_log_label.text = "Vista activa: Modelado 3D"
		return
	if md is String and String(md).begins_with("VIEW2D:"):
		var id: String = String(md).substr("VIEW2D:".length())
		_activate_view2d_from_tree(id)
		return
	if md is String and _is_wall_guid(md):
		_project_view.set_selection(md)
		if _is_edit_mode_active() and md != _edit_mode_guid:
			_exit_edit_mode("")
		_refresh_properties_panel()
		_log_label.text = "Selección (árbol): %s" % md


func _is_wall_guid(s: String) -> bool:
	return s.length() == 22


func _sync_tree_selection(guid: String) -> void:
	if guid == "":
		_project_tree.deselect_all()
		return
	if _wall_tree_items.has(guid):
		var it: TreeItem = _wall_tree_items[guid]
		it.select(0)
		_project_tree.scroll_to_item(it)


func _register_view2d_tree_item(label: String, preset: String) -> String:
	var id: String = "view2d_%d" % _next_view2d_idx
	_next_view2d_idx += 1
	var it: TreeItem = _project_tree.create_item(_views2d_tree_parent)
	it.set_text(0, label)
	it.set_metadata(0, "VIEW2D:%s" % id)
	_view2d_items[id] = it
	_view2d_defs[id] = {"label": label, "preset": preset}
	_view2d_runtime_state[id] = {
		"preset": preset,
		"label": label,
		"state": VIEW2D_STATE_FALLBACK,
		"scale_m_per_px": 1.0,
		"view_range": _default_view_range_for_preset(preset),
	}
	return id


func _default_view_range_for_preset(preset: String) -> Dictionary:
	if preset == "top":
		return {
			"cut_plane_m": DEFAULT_PLAN_CUT_M,
			"top_m": DEFAULT_PLAN_TOP_M,
			"bottom_m": DEFAULT_PLAN_BOTTOM_M,
			"depth_m": DEFAULT_PLAN_DEPTH_M,
		}
	return {
		"cut_plane_m": 0.0,
		"top_m": 10.0,
		"bottom_m": -10.0,
		"depth_m": 10.0,
	}


func _view_tab_for_preset(preset: String) -> int:
	match preset:
		"top":
			return 1
		"front":
			return 2
		"right":
			return 3
		_:
			return 1


func _activate_view2d_from_tree(id: String) -> void:
	if not _view2d_defs.has(id):
		return
	var d: Dictionary = _view2d_defs[id] as Dictionary
	var label: String = str(d.get("label", "Vista 2D"))
	var preset: String = str(d.get("preset", "top"))
	var tab: int = _view_tab_for_preset(preset)
	_view_tabs_bar.current_tab = tab
	if USE_OCC_2D_VIEWS:
		_active_view_tab = tab
		_view_2d_placeholder.visible = true
		%NavGizmo.visible = false
		_render_view2d_for_id(id)
		return
	_on_view_tabs_changed(tab)
	_log_label.text = "Vista 2D activa: %s" % label


func _on_add_view2d_pressed() -> void:
	var preset: String = _tab_to_preset(_active_view_tab)
	if preset == "persp":
		preset = "top"
	var label: String = "Vista 2D %d" % _next_view2d_idx
	var id: String = _register_view2d_tree_item(label, preset)
	if _view2d_items.has(id):
		var it: TreeItem = _view2d_items[id] as TreeItem
		it.select(0)
		_project_tree.scroll_to_item(it)
	_activate_view2d_from_tree(id)


func _on_delete_view2d_pressed() -> void:
	var item: TreeItem = _project_tree.get_selected()
	if item == null:
		return
	var md: Variant = item.get_metadata(0)
	if not (md is String and String(md).begins_with("VIEW2D:")):
		_log_label.text = "Selecciona una vista 2D del Project Browser para eliminarla."
		return
	var id: String = String(md).substr("VIEW2D:".length())
	item.free()
	_view2d_items.erase(id)
	_view2d_defs.erase(id)
	_view2d_runtime_state.erase(id)
	if _view_2d_preview.has_method("clear_snapshot"):
		_view_2d_preview.call("clear_snapshot")
	_view_tabs_bar.current_tab = 0
	_on_view_tabs_changed(0)
	_log_label.text = "Vista 2D eliminada."


func _refresh_properties_panel() -> void:
	var guid: String = _project_view.selected_guid()
	if guid == "":
		_prop_guid_label.text = "GlobalId: —"
		_prop_type_label.text = "Tipo: —"
		_prop_dims_label.text = "Geometría: —"
		_edit_mode_button.text = "Editar elemento"
		_edit_mode_button.disabled = true
		_push_pull_distance.editable = false
		_push_pull_apply_distance_button.disabled = true
		_delete_wall_button.visible = false
		if _wall_tool.is_active():
			_show_wall_typology_trace_mode()
		else:
			_hide_wall_typology_panel()
		return
	_prop_guid_label.text = "GlobalId: %s" % guid
	_prop_type_label.text = "Tipo: IfcWall"
	var ext: Vector3 = _project_view.get_entity_mesh_world_aabb_size(guid)
	if ext != Vector3.ZERO:
		_prop_dims_label.text = "Envolvente aprox. (m): ΔX=%.2f  ΔY=%.2f  ΔZ=%.2f" % [ext.x, ext.y, ext.z]
	else:
		_prop_dims_label.text = "Geometría: —"
	_edit_mode_button.disabled = false
	_edit_mode_button.text = "Salir de edición" if _edit_mode_guid == guid else "Editar elemento"
	_push_pull_distance.editable = _is_edit_mode_active()
	_push_pull_apply_distance_button.disabled = not (
		_is_edit_mode_active() and _push_pull_tool.is_active()
	)
	if _is_wall_guid(guid):
		_delete_wall_button.visible = true
		_show_wall_typology_edit_wall_mode()
		call_deferred("_load_wall_spec_into_panel_async", guid)
	else:
		_delete_wall_button.visible = false
		_hide_wall_typology_panel()


func _hide_wall_typology_panel() -> void:
	_wall_typology_title.visible = false
	_wall_typology_option.visible = false
	_wall_typology_dims.visible = false
	_wall_apply_typology_button.visible = false
	_wall_trace_typology_hint.visible = false


func _delete_wall_shortcut_allowed() -> bool:
	if _gui_focus_is_text_field():
		return false
	var mp := Vector2(DisplayServer.mouse_get_position())
	if not _viewport_container.get_global_rect().has_point(mp):
		return false
	return _is_wall_guid(_project_view.selected_guid())


func _gui_focus_is_text_field() -> bool:
	var fo: Control = get_viewport().gui_get_focus_owner() as Control
	return fo is LineEdit or fo is TextEdit or fo is CodeEdit


func _on_delete_wall_pressed() -> void:
	await _delete_selected_wall_async()


func _show_wall_typology_trace_mode() -> void:
	_wall_typology_title.text = "Tipología / familia (siguiente trazo)"
	_wall_typology_title.visible = true
	_wall_typology_option.visible = true
	_wall_typology_dims.visible = true
	_wall_apply_typology_button.visible = false
	_wall_trace_typology_hint.visible = true
	_wall_trace_typology_hint.text = (
		"Altura y espesor por familia o a mano; se envían al crear cada muro. "
		+ "Para deformar el volumen ya colocado use modo edición + Push/Pull."
	)
	_typology_spin_suppress = true
	_wall_props_height_spin.value = _trace_wall_height
	_wall_props_thickness_spin.value = _trace_wall_thickness
	_typology_spin_suppress = false
	_select_wall_typology_option_from_values(_trace_wall_height, _trace_wall_thickness)


func _show_wall_typology_edit_wall_mode() -> void:
	_wall_typology_title.text = "Tipología / familia (muro)"
	_wall_typology_title.visible = true
	_wall_typology_option.visible = true
	_wall_typology_dims.visible = true
	_wall_apply_typology_button.visible = true
	_wall_trace_typology_hint.visible = false


func _populate_wall_typology_option() -> void:
	_wall_typology_option.set_block_signals(true)
	_wall_typology_option.clear()
	var idx: int = 0
	for d in WALL_FAMILIES:
		var row: Dictionary = d
		_wall_typology_option.add_item(str(row["label"]))
		_wall_typology_option.set_item_metadata(idx, str(row["id"]))
		idx += 1
	_wall_typology_option.add_item("Personalizado")
	_wall_typology_option.set_item_metadata(idx, "CUSTOM")
	_wall_typology_option.set_block_signals(false)


func _select_wall_typology_option_from_values(h: float, t: float) -> void:
	var custom_idx: int = _wall_typology_option.item_count - 1
	_wall_typology_option.set_block_signals(true)
	for i in range(custom_idx):
		var meta: String = str(_wall_typology_option.get_item_metadata(i))
		for d in WALL_FAMILIES:
			var row: Dictionary = d
			if str(row["id"]) != meta:
				continue
			if absf(float(row["h"]) - h) < 0.02 and absf(float(row["t"]) - t) < 0.005:
				_wall_typology_option.select(i)
				_wall_typology_option.set_block_signals(false)
				return
	_wall_typology_option.select(custom_idx)
	_wall_typology_option.set_block_signals(false)


func _on_wall_typology_option_item_selected(_index: int) -> void:
	var tid: String = str(_wall_typology_option.get_item_metadata(_wall_typology_option.selected))
	if tid == "CUSTOM":
		return
	for d in WALL_FAMILIES:
		var row: Dictionary = d
		if str(row["id"]) != tid:
			continue
		_typology_spin_suppress = true
		_wall_props_height_spin.value = float(row["h"])
		_wall_props_thickness_spin.value = float(row["t"])
		_typology_spin_suppress = false
		_on_wall_props_typology_spin_changed(0.0)
		return


func _on_wall_props_typology_spin_changed(_value: float) -> void:
	if _typology_spin_suppress:
		return
	var guid: String = _project_view.selected_guid()
	if guid == "" and _wall_tool.is_active():
		_trace_wall_height = float(_wall_props_height_spin.value)
		_trace_wall_thickness = float(_wall_props_thickness_spin.value)
		_sync_trace_defaults_to_wall_tool()
		_wall_tool.notify_defaults_changed()
	if guid != "" and _is_wall_guid(guid):
		_select_wall_typology_option_from_values(
			float(_wall_props_height_spin.value), float(_wall_props_thickness_spin.value)
		)


func _sync_trace_defaults_to_wall_tool() -> void:
	_wall_tool.default_height = _trace_wall_height
	_wall_tool.default_thickness = _trace_wall_thickness


func _load_wall_spec_into_panel_async(guid: String) -> void:
	var resp: Dictionary = await RpcClient.call_rpc("ifc.get_wall_spec", {"guid": guid})
	if not is_inside_tree():
		return
	if _project_view.selected_guid() != guid:
		return
	if not resp.get("ok", false):
		_log_label.text = "Tipología: %s" % str(resp.get("error", ""))
		return
	var r: Dictionary = resp["result"] as Dictionary
	var ws: Dictionary = r["wall_spec"] as Dictionary
	var h: float = float(ws["height"])
	var t: float = float(ws["thickness"])
	_typology_spin_suppress = true
	_wall_props_height_spin.value = h
	_wall_props_thickness_spin.value = t
	_typology_spin_suppress = false
	_select_wall_typology_option_from_values(h, t)


func _delete_selected_wall_async() -> void:
	var guid: String = _project_view.selected_guid()
	if not _is_wall_guid(guid):
		return
	var resp: Dictionary = await RpcClient.call_rpc("ifc.delete", {"guid": guid})
	if not is_inside_tree():
		return
	if not bool(resp.get("ok", false)):
		_log_label.text = "Eliminar muro: %s" % str(resp.get("error", {}))
		return
	if _edit_mode_guid == guid:
		_exit_edit_mode("")
	_project_view.remove_entity(guid)
	_project_view.clear_selection()
	if _wall_tree_items.has(guid):
		var it: TreeItem = _wall_tree_items[guid] as TreeItem
		it.free()
		_wall_tree_items.erase(guid)
	if _wall_tool.is_active():
		_wall_tool.reset_draft()
	_project_tree.deselect_all()
	_refresh_properties_panel()
	_log_label.text = "Muro eliminado: %s" % guid


func _on_wall_apply_typology_pressed() -> void:
	var guid: String = _project_view.selected_guid()
	if not _is_wall_guid(guid):
		return
	var typology_idx: int = _wall_typology_option.selected
	var tid: String = str(_wall_typology_option.get_item_metadata(typology_idx))
	var params: Dictionary = {
		"guid": guid,
		"height": float(_wall_props_height_spin.value),
		"thickness": float(_wall_props_thickness_spin.value),
	}
	if tid != "CUSTOM":
		params["typology_id"] = tid
	var resp: Dictionary = await RpcClient.call_rpc("ifc.set_wall_typology", params)
	if not is_inside_tree():
		return
	if not resp.get("ok", false):
		_log_label.text = "Aplicar tipología: %s" % str(resp.get("error", ""))
		return
	var res: Dictionary = resp["result"] as Dictionary
	var mesh_dict: Dictionary = res["mesh"] as Dictionary
	_project_view.replace_entity_mesh(guid, mesh_dict)
	_refresh_properties_panel()
	_log_label.text = "Tipología aplicada al muro."


func _refresh_status() -> void:
	_status_label.text = (
		"Backend: conectado" if RpcClient.is_connected_to_backend() else "Backend: desconectado"
	)


func _on_rpc_connected() -> void:
	_refresh_status()


func _on_rpc_disconnected() -> void:
	_refresh_status()


func _on_ping_pressed() -> void:
	_ping_button.disabled = true
	var t0: int = Time.get_ticks_msec()
	var resp: Dictionary = await RpcClient.call_rpc("system.ping", {})
	if not is_inside_tree():
		return
	var rtt: int = Time.get_ticks_msec() - t0
	if resp.get("ok"):
		_rtt_label.text = "RTT: %d ms" % rtt
	else:
		_rtt_label.text = "Error: %s" % str(resp.get("error"))
	_ping_button.disabled = false


func _on_create_wall_pressed() -> void:
	if _wall_tool.is_active():
		_wall_tool.deactivate()
		_set_wall_trace_mode(false)
		_project_view.clear_selection()
		_exit_edit_mode("")
		_refresh_properties_panel()
		_log_label.text = "Crear muro: herramienta cerrada."
		return
	if _active_view_tab == 2 or _active_view_tab == 3:
		_view_tabs_bar.current_tab = 1
		_on_view_tabs_changed(1)
		_log_label.text = (
			"Crear muro: para trazar en 2D se usa Planta (frente/derecha no proyectan al plano XY)."
		)
	_push_pull_tool.deactivate()
	_project_view.clear_selection()
	_exit_edit_mode("")
	_refresh_properties_panel()
	_sync_trace_defaults_to_wall_tool()
	_wall_tool.activate()
	_set_wall_trace_mode(true)
	_log_label.text = (
		"Crear muro: primer trazo P1+P2; los siguientes salen solo con P2 desde el último extremo "
		+ "(Alt+clic = nuevo P1). Esc o botón para salir."
	)


func _on_push_pull_pressed() -> void:
	if _push_pull_tool.is_active():
		_push_pull_tool.deactivate()
		_refresh_properties_panel()
		_log_label.text = "Push/Pull: cancelado"
		return
	if not _is_edit_mode_active():
		_log_label.text = "Entra en modo edición para usar Push/Pull."
		return
	_wall_tool.deactivate()
	_set_wall_trace_mode(false)
	_project_view.set_selection(_edit_mode_guid)
	_refresh_properties_panel()
	_push_pull_tool.activate(_edit_mode_guid)
	_refresh_properties_panel()
	_log_label.text = "Push/Pull: elige una cara del elemento en edición."


func _on_save_pressed() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.ifc ; IFC files"])
	dialog.title = "Guardar proyecto IFC"
	dialog.current_file = "proyecto.ifc"
	dialog.file_selected.connect(_save_to_path.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(640, 400))


func _save_to_path(path: String, dialog: FileDialog) -> void:
	dialog.queue_free()
	var resp: Dictionary = await RpcClient.call_rpc("project.save", {"path": path})
	if not is_inside_tree():
		return
	if resp.get("ok"):
		_log_label.text = "Guardado: %s (%d bytes)" % [path, int(resp["result"].get("bytes", 0))]
	else:
		_log_label.text = "Error al guardar: %s" % str(resp.get("error"))


func _on_export_2d_views_pressed() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "Carpeta destino para vistas 2D (PNG)"
	dialog.dir_selected.connect(_export_2d_views_to_dir.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(760, 460))


func _on_export_wall_dxf_pressed() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "Exportar muros a DXF (planta, metros)"
	dialog.filters = PackedStringArray(["*.dxf ; Drawing Exchange Format"])
	dialog.file_selected.connect(_export_wall_dxf_to_path.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(720, 420))


func _export_wall_dxf_to_path(path: String, dialog: FileDialog) -> void:
	dialog.queue_free()
	if not path.to_lower().ends_with(".dxf"):
		_log_label.text = "Export DXF: la ruta debe terminar en .dxf"
		return
	var resp: Dictionary = await RpcClient.call_rpc(
		"draw.export_dxf_walls",
		{"out_path": path, "view": "top"},
		60000,
	)
	if not is_inside_tree():
		return
	if not bool(resp.get("ok", false)):
		_log_label.text = "Export DXF falló: %s" % str(resp.get("error", {}))
		return
	var r: Dictionary = resp["result"] as Dictionary
	_log_label.text = "DXF exportado: %s (%d segmentos)" % [str(r.get("path", path)), int(r.get("segment_count", 0))]


func _export_2d_views_to_dir(dir_path: String, dialog: FileDialog) -> void:
	dialog.queue_free()
	if USE_OCC_2D_VIEWS:
		await _export_2d_views_occ_to_dir(dir_path)
		return
	await _export_2d_views_legacy_to_dir(dir_path)


func _export_2d_views_legacy_to_dir(dir_path: String) -> void:
	var rig: OrbitRig = _camera_rig as OrbitRig
	if rig == null:
		_log_label.text = "No se pudo exportar vistas 2D: CameraRig inválido."
		return
	var prev: String = rig.current_view_preset()
	var views: Array[String] = ["top", "front", "right"]
	for v in views:
		rig.set_view_preset(v)
		await get_tree().process_frame
		await get_tree().process_frame
		var img: Image = _subviewport.get_texture().get_image()
		var out_path: String = "%s/vista_%s.png" % [dir_path, v]
		var err: int = img.save_png(out_path)
		if err != OK:
			_log_label.text = "Error exportando %s (code=%d)" % [out_path, err]
			rig.set_view_preset(prev)
			return
	rig.set_view_preset(prev)
	_log_label.text = "Vistas 2D exportadas en %s (top/front/right)." % dir_path


func _rasterize_occ_lines_to_image(width_px: int, height_px: int, lines: Array) -> Image:
	var img: Image = Image.create(width_px, height_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.09, 0.10, 0.12, 1.0))
	var ink := Color(0.88, 0.91, 0.98, 1.0)
	for row in lines:
		if not (row is Array) or row.size() < 4:
			continue
		var x0: int = int(round(float(row[0])))
		var y0: int = int(round(float(row[1])))
		var x1: int = int(round(float(row[2])))
		var y1: int = int(round(float(row[3])))
		var dx: int = abs(x1 - x0)
		var sx: int = 1 if x0 < x1 else -1
		var dy: int = -abs(y1 - y0)
		var sy: int = 1 if y0 < y1 else -1
		var err: int = dx + dy
		while true:
			if x0 >= 0 and x0 < width_px and y0 >= 0 and y0 < height_px:
				img.set_pixel(x0, y0, ink)
			if x0 == x1 and y0 == y1:
				break
			var e2: int = err * 2
			if e2 >= dy:
				err += dy
				x0 += sx
			if e2 <= dx:
				err += dx
				y0 += sy
	return img


func _export_2d_views_occ_to_dir(dir_path: String) -> void:
	var views: Array[String] = ["top", "front", "right"]
	for v in views:
		var id: String = _find_view2d_id_by_preset(v)
		var vr: Dictionary = _default_view_range_for_preset(v)
		if id != "" and _view2d_runtime_state.has(id):
			var row: Dictionary = _view2d_runtime_state[id] as Dictionary
			vr = row.get("view_range", vr) as Dictionary
		var resp: Dictionary = await RpcClient.call_rpc(
			"draw.ortho_snapshot",
			{
				"view": v,
				"width_px": max(256, int(_view_2d_preview.size.x)),
				"height_px": max(256, int(_view_2d_preview.size.y)),
				"margin_px": 24,
				"view_range": vr,
				"projection_engine": "analytical",
			},
			30000
		)
		if not bool(resp.get("ok", false)):
			_log_label.text = "OCC export (%s) falló, usando fallback legacy." % v
			await _export_2d_views_legacy_to_dir(dir_path)
			return
		var r: Dictionary = resp["result"] as Dictionary
		var img: Image = _rasterize_occ_lines_to_image(
			int(r.get("width_px", 1200)),
			int(r.get("height_px", 800)),
			r.get("lines_px", []) as Array,
		)
		var out_path: String = "%s/vista_%s.png" % [dir_path, v]
		var err: int = img.save_png(out_path)
		if err != OK:
			_log_label.text = "Error exportando OCC %s (code=%d)" % [out_path, err]
			return
	_log_label.text = "Vistas 2D OCC exportadas en %s (top/front/right)." % dir_path


func _on_push_pull_apply_distance_pressed() -> void:
	if not _push_pull_tool.is_active():
		_log_label.text = "Activa Push/Pull y fija una cara antes de aplicar distancia."
		return
	await _push_pull_tool.apply_numeric_distance(float(_push_pull_distance.value))
	_refresh_properties_panel()


func _unhandled_input(event: InputEvent) -> void:
	var mp := Vector2(DisplayServer.mouse_get_position())
	if not _viewport_container.get_global_rect().has_point(mp):
		return
	if event is InputEventKey and (_camera_rig as OrbitRig).handle_key_view(event as InputEventKey):
		get_viewport().set_input_as_handled()


func _on_viewport_container_gui_input(event: InputEvent) -> void:
	var in_occ_2d: bool = USE_OCC_2D_VIEWS and _active_view_tab != 0
	if event is InputEventMouseButton:
		var mb_dbg: InputEventMouseButton = event
		if mb_dbg.pressed and mb_dbg.button_index == MOUSE_BUTTON_LEFT:
			# #region agent log
			_agent_debug_log(
				"pre-fix-2",
				"H5",
				"main_scene.gd:_on_viewport_container_gui_input",
				"left click dispatch state",
				{
					"in_occ_2d": in_occ_2d,
					"wall_tool_active": _wall_tool.is_active(),
					"active_tab": _active_view_tab,
				},
			)
			# #endregion
	if in_occ_2d and _view_2d_preview.has_method("handle_input"):
		var consumed_2d: bool = bool(_view_2d_preview.call("handle_input", event))
		if consumed_2d:
			_viewport_container.get_viewport().set_input_as_handled()
			_refresh_workspace_hud()
			return
	# En OCC 2D + trazo de muro activo no se permite navegar la camara 3D.
	if not (in_occ_2d and _wall_tool.is_active()) and (_camera_rig as OrbitRig).handle_viewport_gui_input(event):
		_viewport_container.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _wall_tool.is_active():
			if in_occ_2d and _view_2d_preview.has_method("to_projected_world_uv"):
				var uv_mm: Vector2 = _view_2d_preview.call("to_projected_world_uv", mm.position)
				if not (is_inf(uv_mm.x) or is_inf(uv_mm.y)):
					_has_last_valid_occ_uv = true
					_last_valid_occ_uv = uv_mm
					var pwm: Vector3 = _occ_uv_to_floor_point_world(uv_mm)
					_wall_tool.handle_viewport_motion_world_floor(pwm)
				else:
					var pos_fallback_m: Vector2 = _subviewport.get_mouse_position()
					if in_occ_2d and _view_2d_preview.has_method("to_snapshot_space"):
						pos_fallback_m = _view_2d_preview.call("to_snapshot_space", mm.position)
					# #region agent log
					_agent_debug_log(
						"post-fix",
						"H5",
						"main_scene.gd:_on_viewport_container_gui_input",
						"motion fallback to 3d projection due invalid uv",
						{"mouse_x": mm.position.x, "mouse_y": mm.position.y},
					)
					# #endregion
					_wall_tool.handle_viewport_motion(pos_fallback_m)
			else:
				var pos_m: Vector2 = _subviewport.get_mouse_position()
				if in_occ_2d and _view_2d_preview.has_method("to_snapshot_space"):
					pos_m = _view_2d_preview.call("to_snapshot_space", mm.position)
				_wall_tool.handle_viewport_motion(pos_m)
		if _push_pull_tool.is_active() and _push_pull_tool.is_selecting_face():
			_project_view.update_face_hover_at_screen(_camera, _subviewport.get_mouse_position())
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if in_occ_2d and _wall_tool.is_active() and _view_2d_preview.has_method("to_projected_world_uv"):
				var uv_cl: Vector2 = _view_2d_preview.call("to_projected_world_uv", mb.position)
				# #region agent log
				_agent_debug_log(
					"pre-fix-2",
					"H5",
					"main_scene.gd:_on_viewport_container_gui_input",
					"2d projected uv from click",
					{"uv_x": uv_cl.x, "uv_y": uv_cl.y, "mouse_x": mb.position.x, "mouse_y": mb.position.y},
				)
				# #endregion
				if not (is_inf(uv_cl.x) or is_inf(uv_cl.y)):
					_has_last_valid_occ_uv = true
					_last_valid_occ_uv = uv_cl
					var pwc: Vector3 = _occ_uv_to_floor_point_world(uv_cl)
					# #region agent log
					_agent_debug_log(
						"pre-fix-2",
						"H5",
						"main_scene.gd:_on_viewport_container_gui_input",
						"2d floor world point for wall click",
						{"x": pwc.x, "y": pwc.y, "z": pwc.z},
					)
					# #endregion
					_wall_tool.handle_viewport_click_world_floor(pwc)
				else:
					# #region agent log
					_agent_debug_log(
						"post-fix",
						"H5",
						"main_scene.gd:_on_viewport_container_gui_input",
						"click fallback to 3d projection due invalid uv",
						{"mouse_x": mb.position.x, "mouse_y": mb.position.y},
					)
					# #endregion
					if _has_last_valid_occ_uv:
						var pwc_last: Vector3 = _occ_uv_to_floor_point_world(_last_valid_occ_uv)
						_wall_tool.handle_viewport_click_world_floor(pwc_last)
						_viewport_container.get_viewport().set_input_as_handled()
						return
					var pos_fallback: Vector2 = _subviewport.get_mouse_position()
					if in_occ_2d and _view_2d_preview.has_method("to_snapshot_space"):
						pos_fallback = _view_2d_preview.call("to_snapshot_space", mb.position)
					_wall_tool.handle_viewport_click(pos_fallback)
				_viewport_container.get_viewport().set_input_as_handled()
				return
			var pos: Vector2 = _subviewport.get_mouse_position()
			if in_occ_2d and _view_2d_preview.has_method("to_snapshot_space"):
				pos = _view_2d_preview.call("to_snapshot_space", mb.position)
			if _wall_tool.is_active():
				_wall_tool.handle_viewport_click(pos)
			elif _push_pull_tool.is_active():
				_push_pull_tool.handle_viewport_click(pos)
			else:
				var picked: String = _project_view.pick_entity_at_screen(_camera, pos)
				var is_double_click: bool = mb.double_click and picked != ""
				_sync_tree_selection(picked)
				if _is_edit_mode_active() and picked != _edit_mode_guid:
					_exit_edit_mode("")
				_refresh_properties_panel()
				if is_double_click:
					_enter_edit_mode(picked)
				elif picked != "":
					_log_label.text = "Seleccionado: %s" % picked
				else:
					_log_label.text = "Sin selección (clic en vacío)"
			_viewport_container.get_viewport().set_input_as_handled()


func _on_wall_draft_hint(text: String) -> void:
	_wall_draft_hint.text = text


func _cancel_wall_tool_with_esc() -> void:
	_wall_tool.deactivate()
	_set_wall_trace_mode(false)
	_project_view.clear_selection()
	_exit_edit_mode("")
	_refresh_properties_panel()
	_log_label.text = "Crear muro: cancelado (Esc)."


func _sync_wall_defaults_from_selected_wall_if_possible() -> void:
	var guid: String = _project_view.selected_guid()
	if guid == "" or not _project_view.has_entity(guid):
		return
	var ext: Vector3 = _project_view.get_entity_mesh_world_aabb_size(guid)
	if ext == Vector3.ZERO:
		return
	if ext.z >= maxf(ext.x, ext.y) * 0.55:
		_typology_spin_suppress = true
		_wall_props_thickness_spin.value = clampf(minf(ext.x, ext.y), 0.05, 2.0)
		_wall_props_height_spin.value = clampf(ext.z, 0.5, 60.0)
		_typology_spin_suppress = false
		_on_wall_props_typology_spin_changed(0.0)


func _on_wall_created(guid: String, workspace_half_xy: Vector2) -> void:
	var preset: String = _tab_to_preset(_active_view_tab)
	var view2d_id: String = _find_view2d_id_by_preset(preset) if preset != "persp" else ""
	_workspace_xy_half_cached = workspace_half_xy
	_refresh_workspace_hud()
	var item: TreeItem = _project_tree.create_item(_muros_tree_parent)
	var short_id: String = guid.substr(0, 8) if guid.length() >= 8 else guid
	item.set_text(0, "Muro %s…" % short_id)
	item.set_metadata(0, guid)
	_wall_tree_items[guid] = item
	item.select(0)
	_project_view.set_selection(guid)
	_refresh_properties_panel()
	if USE_OCC_2D_VIEWS and preset != "persp" and view2d_id != "":
		_schedule_occ_view2d_refresh_after_wall(view2d_id)
	_log_label.text = "Muro creado: %s (total=%d)" % [guid, _project_view.entity_count()]


func _on_edit_mode_button_pressed() -> void:
	var guid: String = _project_view.selected_guid()
	if _is_edit_mode_active():
		_exit_edit_mode("Modo edición: cerrado")
	elif guid != "":
		_enter_edit_mode(guid)


func _enter_edit_mode(guid: String) -> void:
	if guid == "" or not _project_view.has_entity(guid):
		return
	_wall_tool.deactivate()
	_push_pull_tool.deactivate()
	_edit_mode_guid = guid
	_project_view.set_selection(guid)
	_project_view.set_edit_target(guid)
	_sync_tree_selection(guid)
	_refresh_properties_panel()
	_log_label.text = "Modo edición: %s. Usa Push/Pull o Esc para salir." % guid


func _exit_edit_mode(message: String) -> void:
	if _edit_mode_guid == "":
		return
	_edit_mode_guid = ""
	_push_pull_tool.deactivate()
	_project_view.clear_edit_target()
	_refresh_properties_panel()
	if message != "":
		_log_label.text = message


func _is_edit_mode_active() -> bool:
	return _edit_mode_guid != ""
