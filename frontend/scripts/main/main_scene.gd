# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Escena raiz de AxonBIM (Fase 2 — UI cinta + Push/Pull + undo RPC).

const OrbitRig := preload("res://scripts/viewport_3d/orbit_camera_rig.gd")
const CreateWallTool := preload("res://scripts/tools/create_wall_tool.gd")
const PushPullTool := preload("res://scripts/tools/push_pull_tool.gd")
const _ViewportManagerGd := preload("res://scripts/viewport_3d/viewport_manager.gd")

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
const USE_OCC_2D_VIEWS: bool = false
## Árbol de diagnóstico RPC (EventBus). Desactivado por defecto; activar solo en desarrollo.
const EXPERIMENTAL_EVENTBUS_RPC_INSPECTOR: bool = false
const VIEW2D_STATE_LOADING: String = "loading"
const VIEW2D_STATE_READY: String = "ready"
const VIEW2D_STATE_ERROR: String = "error"
const VIEW2D_STATE_FALLBACK: String = "fallback"
const VIEW2D_MODE_AUTO: String = "auto"
const VIEW2D_MODE_VECTORIAL: String = "vectorial"
const VIEW2D_MODE_ORTHO: String = "ortho"
const VIS_STYLE_ARCH: String = "arch"
const VIS_STYLE_CONTRAST: String = "contrast"
const VIS_STYLE_WIREFRAME: String = "wireframe"
const SCALE_2D_PRESETS: Array = [20, 50, 75, 200, 500]
const DEFAULT_PLAN_CUT_M: float = 1.2
const DEFAULT_PLAN_BOTTOM_M: float = 0.0
const DEFAULT_PLAN_TOP_M: float = 3.0
const DEFAULT_PLAN_DEPTH_M: float = 1.2
const KB_WALL_STEP_FINE_M: float = 0.10
const KB_WALL_STEP_COARSE_M: float = 0.50
const FLOAT_SNAP_THRESHOLD_PX: int = 36

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

var _viewport_manager: _ViewportManagerGd
var _experimental_rpc_tree: Tree = null
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
@onready var _ribbon: Control = $UI/Root/Ribbon
@onready var _ribbon_body: Control = $UI/Root/Ribbon/RibbonBody
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
@onready var _left_dock: Control = $UI/Root/Workspace/MainSplit/LeftDock
@onready var _right_dock: Control = $UI/Root/Workspace/MainSplit/InnerSplit/RightDock
@onready var _left_dock_header: Control = $UI/Root/Workspace/MainSplit/LeftDock/LeftDockHeader
@onready var _right_dock_header: Control = $UI/Root/Workspace/MainSplit/InnerSplit/RightDock/RightDockHeader

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
var _view2d_mode_before_wall: String = ""
var _has_last_valid_occ_uv: bool = false
var _last_valid_occ_uv: Vector2 = Vector2.ZERO
var _kb_wall_cursor_world: Vector3 = Vector3.ZERO
var _kb_wall_cursor_ready: bool = false
var _visual_style_current: String = VIS_STYLE_ARCH
var _visual_style_option: OptionButton
var _scale_2d_preset_option: OptionButton
var _scale_2d_custom_spin: SpinBox
var _workspace_tabs_host_top: PanelContainer
var _workspace_tool_context_row: HBoxContainer
var _mini_view_tabs: TabBar
var _floating_views: Dictionary = {}  # int tab_idx -> Window
var _floating_viewports: Dictionary = {}  # int tab_idx -> {subviewport,camera,rig,host}
var _view_state_by_tab: Dictionary = {}  # int -> {name,preset,camera,view_range,visual_style,is_default}
var _workspace_floating_windows: Dictionary = {}  # "left"/"right" -> Window
var _workspace_dock_slots: Dictionary = {}  # "left"/"right" -> {parent,index}
var _suppress_auto_snap: bool = false
var _snap_guide_overlay: ColorRect
var _saved_tab_before_switch: int = -1
var _view_name_seq: int = 1


func _log_info(message: String) -> void:
	var logger: Node = get_node_or_null("/root/Logger")
	if logger != null and logger.has_method("info"):
		logger.call("info", message)
	else:
		print("[INFO ] ", message)


func _on_eventbus_system_warning(message: String, level: String) -> void:
	if message.is_empty():
		return
	var prefix: String = "[backend %s] " % level
	_log_info(prefix + message)
	if _status_label != null:
		_status_label.tooltip_text = prefix + message


func _on_eventbus_backend_info(message: String) -> void:
	if message.is_empty():
		return
	_log_info("[backend info] " + message)


func _on_eventbus_backend_notification(method: String, params: Dictionary) -> void:
	if method == "project.state_changed":
		_log_info("Estado proyecto (notificación): %s" % str(params.get("state", params)))


func _setup_experimental_eventbus_inspector() -> void:
	if not EXPERIMENTAL_EVENTBUS_RPC_INSPECTOR:
		return
	var host: Node = _prop_guid_label.get_parent()
	if host == null:
		return
	host.add_child(HSeparator.new())
	var caption := Label.new()
	caption.text = "RPC notificaciones (experimental)"
	host.add_child(caption)
	_experimental_rpc_tree = Tree.new()
	_experimental_rpc_tree.custom_minimum_size = Vector2(0, 140)
	_experimental_rpc_tree.columns = 2
	_experimental_rpc_tree.hide_root = true
	host.add_child(_experimental_rpc_tree)
	EventBus.backend_notification.connect(_on_experimental_inspector_notification)


func _on_experimental_inspector_notification(method: String, params: Dictionary) -> void:
	if _experimental_rpc_tree == null:
		return
	_experimental_rpc_tree.clear()
	var hidden_root: TreeItem = _experimental_rpc_tree.create_item()
	var row: TreeItem = _experimental_rpc_tree.create_item(hidden_root)
	row.set_text(0, method)
	row.set_text(1, JSON.stringify(params))


func _ready() -> void:
	_viewport_manager = _ViewportManagerGd.new()
	_viewport_manager.setup(_subviewport, USE_OCC_2D_VIEWS)
	_log_info("AxonBIM frontend iniciado (Fase 2 · UI cinta + acoples).")
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
	EventBus.system_warning.connect(_on_eventbus_system_warning)
	EventBus.backend_info.connect(_on_eventbus_backend_info)
	EventBus.backend_notification.connect(_on_eventbus_backend_notification)
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
	_init_default_view_states()
	_ensure_viewport_bottom_palette()
	_install_workspace_top_bars()
	_ensure_view_tab_top_controls()
	_install_workspace_modularity_controls()
	_ensure_snap_guide_overlay()
	call_deferred("_refresh_workspace_hud")
	_update_view2d_mode_button_text()
	_on_view_tabs_changed(_view_tabs_bar.current_tab)
	_refresh_ribbon_compact_mode()
	_setup_experimental_eventbus_inspector()


func _physics_process(_delta: float) -> void:
	_hud_ticks += 1
	for tab_key in _floating_views.keys():
		_on_auto_snap_window_moved("view", int(tab_key))
	if _hud_ticks % 12 != 0:
		return
	_save_active_view_state(_active_view_tab)
	_save_open_floating_view_states()
	_refresh_workspace_hud()


func _sync_floating_viewport_cameras() -> void:
	for k in _floating_viewports.keys():
		var tab_idx: int = int(k)
		if not _view_state_by_tab.has(tab_idx):
			continue
		var slot: Dictionary = _floating_viewports[k] as Dictionary
		var rig: OrbitRig = slot.get("rig") as OrbitRig
		var cam: Camera3D = slot.get("camera") as Camera3D
		var row: Dictionary = _view_state_by_tab[tab_idx] as Dictionary
		var cam_state: Dictionary = row.get("camera", {}) as Dictionary
		if rig != null and not cam_state.is_empty():
			rig.apply_view_state(cam_state)
		var snap: Dictionary = row.get("camera_snapshot", {}) as Dictionary
		_apply_camera_snapshot_to_camera(cam, snap)


func _save_open_floating_view_states() -> void:
	for k in _floating_viewports.keys():
		var tab_idx: int = int(k)
		if not _view_state_by_tab.has(tab_idx):
			continue
		var slot: Dictionary = _floating_viewports[k] as Dictionary
		var rig: OrbitRig = slot.get("rig") as OrbitRig
		var cam: Camera3D = slot.get("camera") as Camera3D
		var row: Dictionary = _view_state_by_tab[tab_idx] as Dictionary
		if rig != null:
			row["camera"] = rig.capture_view_state()
		if cam != null:
			row["camera_snapshot"] = _capture_camera_snapshot_from(cam)
		_view_state_by_tab[tab_idx] = row


func _refresh_workspace_hud() -> void:
	if _workspace_hud == null:
		return
	var cam_hint := ""
	if is_instance_valid(_camera_rig) and _camera_rig.has_method("get_viewport_scale_hint_fragment"):
		cam_hint = str(_camera_rig.get_viewport_scale_hint_fragment())
	var occ_hint: String = ""
	if _active_view_tab != 0 and _view_state_by_tab.has(_active_view_tab):
		var row: Dictionary = _view_state_by_tab[_active_view_tab] as Dictionary
		var vr: Dictionary = row.get("view_range", {}) as Dictionary
		occ_hint = (
			" | %s · corte %.2fm · top %.2fm · bottom %.2fm"
			% [
				str(row.get("name", "Vista")),
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
func _sync_main_subviewport_render_policy() -> void:
	if _viewport_manager == null:
		return
	var occluded: bool = _floating_views.has(_active_view_tab)
	_viewport_manager.update_main_canvas_render_policy(_active_view_tab, occluded)


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
	if _active_view_tab != tab:
		_save_active_view_state(_active_view_tab)
	_active_view_tab = tab
	_has_last_valid_occ_uv = false
	var modelado: bool = tab == 0
	_sync_main_subviewport_render_policy()
	_workspace_hud.visible = true
	_view_2d_placeholder.visible = false
	%NavGizmo.visible = modelado
	var rig: OrbitRig = _camera_rig as OrbitRig
	if rig == null:
		_sync_mini_tabs_from_main()
		_apply_visual_style(_visual_style_current)
		return
	rig.set_orthographic_zoom_locked(false)
	_apply_view_state_for_tab(tab)
	if modelado:
		_log_label.text = "Vista activa: Modelado 3D (interactivo)."
	else:
		_log_label.text = "Vista activa: %s (modelo único en ortográfica)." % _view_tabs_bar.get_tab_title(tab)
	_sync_mini_tabs_from_main()
	_refresh_top_palette_controls()
	_apply_visual_style(_visual_style_current)
	_refresh_main_viewport_docked_state()


func _default_view_range_for_tab(tab: int) -> Dictionary:
	if tab == 1:
		return {
			"cut_plane_m": DEFAULT_PLAN_CUT_M,
			"top_m": DEFAULT_PLAN_TOP_M,
			"bottom_m": DEFAULT_PLAN_BOTTOM_M,
			"depth_m": DEFAULT_PLAN_DEPTH_M,
		}
	return {"cut_plane_m": 0.0, "top_m": 10.0, "bottom_m": -10.0, "depth_m": 10.0}


func _preset_for_tab(tab: int) -> String:
	match tab:
		0:
			return "persp"
		1:
			return "top"
		2:
			return "front"
		3:
			return "right"
		_:
			return "top"


func _default_view_name_for_tab(tab: int) -> String:
	match tab:
		0:
			return "Modelado 3D"
		1:
			return "Planta Nivel 00"
		2:
			return "Frente A"
		3:
			return "Derecha A"
		_:
			return "Vista %d" % tab


func _init_default_view_states() -> void:
	var rig: OrbitRig = _camera_rig as OrbitRig
	for i in range(_view_tabs_bar.tab_count):
		var preset: String = _preset_for_tab(i)
		rig.set_view_preset(preset)
		_view_state_by_tab[i] = {
			"name": _default_view_name_for_tab(i),
			"preset": preset,
			"camera": rig.capture_view_state(),
			"camera_snapshot": _capture_main_camera_snapshot(),
			"view_range": _default_view_range_for_tab(i),
			"visual_style": _visual_style_current,
			"scale_2d": 1.0,
			"is_default": i <= 3,
		}
		_view_tabs_bar.set_tab_title(i, str(_view_state_by_tab[i]["name"]))
	rig.set_view_preset("persp")


func _create_or_reuse_view_tab(name: String, preset: String, view_range: Dictionary, is_default: bool) -> int:
	for k in _view_state_by_tab.keys():
		var idx: int = int(k)
		var row: Dictionary = _view_state_by_tab[k] as Dictionary
		if str(row.get("name", "")) == name:
			return idx
	var tab_idx: int = _view_tabs_bar.tab_count
	_view_tabs_bar.add_tab(name)
	var rig: OrbitRig = _camera_rig as OrbitRig
	rig.set_view_preset(preset)
	_view_state_by_tab[tab_idx] = {
		"name": name,
		"preset": preset,
		"camera": rig.capture_view_state(),
		"camera_snapshot": _capture_main_camera_snapshot(),
		"view_range": view_range.duplicate(true),
		"visual_style": _visual_style_current,
		"scale_2d": 1.0,
		"is_default": is_default,
	}
	return tab_idx


func _save_active_view_state(tab: int) -> void:
	if tab < 0 or not _view_state_by_tab.has(tab):
		return
	var rig: OrbitRig = _camera_rig as OrbitRig
	var row: Dictionary = _view_state_by_tab[tab] as Dictionary
	row["camera"] = rig.capture_view_state()
	row["camera_snapshot"] = _capture_main_camera_snapshot()
	row["visual_style"] = _visual_style_current
	_view_state_by_tab[tab] = row


func _apply_view_state_for_tab(tab: int) -> void:
	if not _view_state_by_tab.has(tab):
		return
	var rig: OrbitRig = _camera_rig as OrbitRig
	var row: Dictionary = _view_state_by_tab[tab] as Dictionary
	var cam: Dictionary = row.get("camera", {}) as Dictionary
	if cam.is_empty():
		rig.set_view_preset(str(row.get("preset", _preset_for_tab(tab))))
	else:
		rig.apply_view_state(cam)
	var style: String = str(row.get("visual_style", VIS_STYLE_ARCH))
	_visual_style_current = style
	if _visual_style_option != null:
		for i in range(_visual_style_option.item_count):
			if str(_visual_style_option.get_item_metadata(i)) == style:
				_visual_style_option.select(i)
				break


func _capture_main_camera_snapshot() -> Dictionary:
	return _capture_camera_snapshot_from(_camera)


func _capture_camera_snapshot_from(cam: Camera3D) -> Dictionary:
	return {
		"transform": cam.global_transform,
		"projection": cam.projection,
		"fov": cam.fov,
		"size": cam.size,
		"near": cam.near,
		"far": cam.far,
	}


func _apply_camera_snapshot_to_camera(cam: Camera3D, snap: Dictionary) -> void:
	if cam == null or snap.is_empty():
		return
	if snap.has("transform"):
		cam.global_transform = snap["transform"] as Transform3D
	if snap.has("projection"):
		cam.projection = int(snap["projection"])
	if snap.has("fov"):
		cam.fov = float(snap["fov"])
	if snap.has("size"):
		cam.size = float(snap["size"])
	if snap.has("near"):
		cam.near = float(snap["near"])
	if snap.has("far"):
		cam.far = float(snap["far"])


func _ensure_viewport_bottom_palette() -> void:
	if _visual_style_option != null:
		return
	var strip: PanelContainer = PanelContainer.new()
	strip.name = "ViewportBottomPalette"
	strip.custom_minimum_size = Vector2(640.0, 40.0)
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	var root: Control = get_node_or_null("UI/Root")
	if root == null:
		return
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_left = 8.0
	strip.offset_right = -8.0
	strip.offset_top = -44.0
	strip.offset_bottom = -4.0
	root.add_child(strip)
	var status_bar: Control = _log_label.get_parent() as Control
	if status_bar != null:
		root.move_child(strip, maxi(0, status_bar.get_index()))
	strip.z_index = 95
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)
	strip.add_child(row)
	var style_lbl: Label = Label.new()
	style_lbl.text = "Estilo visual"
	row.add_child(style_lbl)
	_visual_style_option = OptionButton.new()
	_visual_style_option.add_item("Arquitectonico", 0)
	_visual_style_option.set_item_metadata(0, VIS_STYLE_ARCH)
	_visual_style_option.add_item("Alto contraste", 1)
	_visual_style_option.set_item_metadata(1, VIS_STYLE_CONTRAST)
	_visual_style_option.add_item("Alambrico", 2)
	_visual_style_option.set_item_metadata(2, VIS_STYLE_WIREFRAME)
	_visual_style_option.select(0)
	_visual_style_option.item_selected.connect(_on_visual_style_selected)
	row.add_child(_visual_style_option)
	var scale_lbl: Label = Label.new()
	scale_lbl.text = "Escala 2D"
	row.add_child(scale_lbl)
	_scale_2d_preset_option = OptionButton.new()
	for den in SCALE_2D_PRESETS:
		_scale_2d_preset_option.add_item("1:%d" % int(den))
	_scale_2d_preset_option.add_item("Custom")
	_scale_2d_preset_option.custom_minimum_size = Vector2(120.0, 0.0)
	_scale_2d_preset_option.item_selected.connect(_on_workspace_scale_preset_selected)
	row.add_child(_scale_2d_preset_option)
	_scale_2d_custom_spin = SpinBox.new()
	_scale_2d_custom_spin.min_value = 10.0
	_scale_2d_custom_spin.max_value = 2000.0
	_scale_2d_custom_spin.step = 5.0
	_scale_2d_custom_spin.custom_minimum_size = Vector2(96.0, 0.0)
	_scale_2d_custom_spin.prefix = "1:"
	_scale_2d_custom_spin.value_changed.connect(_on_workspace_custom_den_changed)
	row.add_child(_scale_2d_custom_spin)
	_apply_panel_style(strip, UI_PANEL_ELEVATED, UI_BORDER, 10)
	_style_label(style_lbl, UI_TEXT)
	_style_label(scale_lbl, UI_TEXT)
	_refresh_top_palette_controls()
	_apply_visual_style(_visual_style_current)


func _install_workspace_top_bars() -> void:
	var workspace: VBoxContainer = get_node_or_null("UI/Root/Workspace")
	if workspace == null or workspace.has_node("WorkspaceTopBars"):
		return
	var top_strip: PanelContainer = PanelContainer.new()
	top_strip.name = "WorkspaceTopBars"
	top_strip.custom_minimum_size = Vector2(0.0, 40.0)
	workspace.add_child(top_strip)
	workspace.move_child(top_strip, 0)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_strip.add_child(row)
	var host: Control = _view_tabs_bar.get_parent() as Control
	if host != null:
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		row.add_child(host)
		host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.custom_minimum_size = Vector2(560.0, 30.0)
		host.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tool_row: HBoxContainer = HBoxContainer.new()
	tool_row.name = "WorkspaceToolContextRow"
	tool_row.add_theme_constant_override("separation", 6)
	row.add_child(tool_row)
	_workspace_tabs_host_top = top_strip
	_workspace_tool_context_row = tool_row
	_rebuild_tool_context_row()
	_apply_panel_style(top_strip, UI_PANEL_ELEVATED, UI_BORDER, 10)


func _rebuild_tool_context_row() -> void:
	if _workspace_tool_context_row == null:
		return
	for c in _workspace_tool_context_row.get_children():
		c.queue_free()
	var float_btn: Button = Button.new()
	float_btn.text = "Flotar vista"
	float_btn.icon = load("res://assets/icons/actions/action_ping_backend.svg")
	float_btn.pressed.connect(_on_float_active_view_pressed)
	_workspace_tool_context_row.add_child(float_btn)
	var close_btn: Button = Button.new()
	close_btn.text = "Cerrar vista"
	close_btn.icon = load("res://assets/icons/actions/action_undo.svg")
	close_btn.pressed.connect(_on_delete_view2d_pressed)
	_workspace_tool_context_row.add_child(close_btn)
	var wall_btn: Button = Button.new()
	wall_btn.text = "Muro"
	wall_btn.icon = load("res://assets/icons/tools/tool_create_wall.svg")
	wall_btn.pressed.connect(_on_create_wall_pressed)
	_workspace_tool_context_row.add_child(wall_btn)
	var edit_btn: Button = Button.new()
	edit_btn.text = "Editar"
	edit_btn.icon = load("res://assets/icons/tools/tool_edit_element.svg")
	edit_btn.pressed.connect(_on_edit_mode_button_pressed)
	_workspace_tool_context_row.add_child(edit_btn)
	var pp_btn: Button = Button.new()
	pp_btn.text = "Push/Pull"
	pp_btn.icon = load("res://assets/icons/tools/tool_push_pull.svg")
	pp_btn.pressed.connect(_on_push_pull_pressed)
	_workspace_tool_context_row.add_child(pp_btn)
	_apply_button_style(float_btn, UI_ACCENT_BLUE)
	_apply_button_style(close_btn, UI_ACCENT_DANGER)
	_apply_button_style(wall_btn, UI_ACCENT_BLUE)
	_apply_button_style(edit_btn, UI_ACCENT_AMBER)
	_apply_button_style(pp_btn, UI_ACCENT_AMBER)


func _ensure_view_tab_top_controls() -> void:
	if _workspace_tool_context_row != null:
		return
	var host: Control = _view_tabs_bar.get_parent() as Control
	if host == null or host.has_node("ViewTabTopControls"):
		return
	_view_tabs_bar.custom_minimum_size = Vector2(0.0, 28.0)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ViewTabTopControls"
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_right = -8.0
	row.offset_top = 2.0
	row.add_theme_constant_override("separation", 4)
	var float_btn: Button = Button.new()
	float_btn.text = "Flotar"
	float_btn.pressed.connect(_on_float_active_view_pressed)
	row.add_child(float_btn)
	var close_btn: Button = Button.new()
	close_btn.text = "Cerrar"
	close_btn.pressed.connect(_on_delete_view2d_pressed)
	row.add_child(close_btn)
	_apply_button_style(float_btn, UI_ACCENT_BLUE)
	_apply_button_style(close_btn, UI_ACCENT_DANGER)
	host.add_child(row)


func _install_workspace_modularity_controls() -> void:
	_install_dock_toggle_button(_left_dock_header, "Desacoplar", "left")
	_install_dock_toggle_button(_right_dock_header, "Desacoplar", "right")
	_refresh_workspace_dock_toggle_row("left")
	_refresh_workspace_dock_toggle_row("right")


func _install_dock_toggle_button(header: Control, label: String, side: String) -> void:
	if header == null:
		return
	var row: HBoxContainer = header.get_node_or_null("DockToggleRow")
	if row == null:
		row = HBoxContainer.new()
		row.name = "DockToggleRow"
		row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		row.offset_right = -8.0
		row.offset_top = 4.0
		header.add_child(row)
	if row.get_node_or_null("DockSnapLeft") == null:
		var snap_left_btn: Button = Button.new()
		snap_left_btn.name = "DockSnapLeft"
		snap_left_btn.text = "Snap Izq"
		snap_left_btn.pressed.connect(_on_snap_workspace_panel.bind(side, "left"))
		row.add_child(snap_left_btn)
		_apply_button_style(snap_left_btn, UI_ACCENT_BLUE)
	if row.get_node_or_null("DockSnapRight") == null:
		var snap_right_btn: Button = Button.new()
		snap_right_btn.name = "DockSnapRight"
		snap_right_btn.text = "Snap Der"
		snap_right_btn.pressed.connect(_on_snap_workspace_panel.bind(side, "right"))
		row.add_child(snap_right_btn)
		_apply_button_style(snap_right_btn, UI_ACCENT_BLUE)
	if row.get_node_or_null("DockSnapTop") == null:
		var snap_top_btn: Button = Button.new()
		snap_top_btn.name = "DockSnapTop"
		snap_top_btn.text = "Snap Arriba"
		snap_top_btn.pressed.connect(_on_snap_workspace_panel.bind(side, "top"))
		row.add_child(snap_top_btn)
		_apply_button_style(snap_top_btn, UI_ACCENT_BLUE)
	if row.get_node_or_null("DockRedock") == null:
		var redock_btn: Button = Button.new()
		redock_btn.name = "DockRedock"
		redock_btn.text = "Acoplar"
		redock_btn.pressed.connect(_redock_workspace_panel.bind(side))
		row.add_child(redock_btn)
		_apply_button_style(redock_btn, UI_ACCENT_DANGER)
	var btn: Button = Button.new()
	btn.name = "DockToggleMain"
	btn.text = label
	btn.pressed.connect(_on_toggle_workspace_dock.bind(side))
	row.add_child(btn)
	_apply_button_style(btn, UI_ACCENT_BLUE)


func _refresh_workspace_dock_toggle_row(side: String) -> void:
	var header: Control = _left_dock_header if side == "left" else _right_dock_header
	if header == null:
		return
	var row: HBoxContainer = header.get_node_or_null("DockToggleRow")
	if row == null:
		return
	var is_floating: bool = _workspace_floating_windows.has(side)
	var main_btn: Button = row.get_node_or_null("DockToggleMain")
	var snap_left_btn: Button = row.get_node_or_null("DockSnapLeft")
	var snap_right_btn: Button = row.get_node_or_null("DockSnapRight")
	var snap_top_btn: Button = row.get_node_or_null("DockSnapTop")
	var redock_btn: Button = row.get_node_or_null("DockRedock")
	if main_btn != null:
		main_btn.visible = not is_floating
	if snap_left_btn != null:
		snap_left_btn.visible = is_floating
	if snap_right_btn != null:
		snap_right_btn.visible = is_floating
	if snap_top_btn != null:
		snap_top_btn.visible = is_floating
	if redock_btn != null:
		redock_btn.visible = is_floating


func _on_toggle_workspace_dock(side: String) -> void:
	if _workspace_floating_windows.has(side):
		_redock_workspace_panel(side)
	else:
		_undock_workspace_panel(side)


func _on_snap_workspace_panel(side: String, zone: String) -> void:
	if not _workspace_floating_windows.has(side):
		return
	var win: Window = _workspace_floating_windows[side]
	_snap_window_to_zone(win, zone)


func _undock_workspace_panel(side: String) -> void:
	var panel: Control = _left_dock if side == "left" else _right_dock
	if panel == null or panel.get_parent() == null:
		return
	var parent: Node = panel.get_parent()
	var idx: int = panel.get_index()
	_workspace_dock_slots[side] = {"parent": parent, "index": idx}
	parent.remove_child(panel)
	var win: Window = Window.new()
	win.title = "Panel %s" % ("izquierdo" if side == "left" else "derecho")
	win.size = Vector2i(360, 760)
	add_child(win)
	win.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	win.close_requested.connect(_redock_workspace_panel.bind(side))
	_workspace_floating_windows[side] = win
	win.popup_centered()
	_snap_window_to_zone(win, "left" if side == "left" else "right")
	_refresh_workspace_dock_toggle_row(side)


func _redock_workspace_panel(side: String) -> void:
	if not _workspace_floating_windows.has(side):
		return
	var win: Window = _workspace_floating_windows[side]
	var panel: Control = _left_dock if side == "left" else _right_dock
	if panel.get_parent() == win:
		win.remove_child(panel)
	var slot: Dictionary = _workspace_dock_slots.get(side, {}) as Dictionary
	var parent: Node = slot.get("parent")
	var idx: int = int(slot.get("index", -1))
	if parent != null:
		parent.add_child(panel)
		if idx >= 0:
			parent.move_child(panel, mini(idx, parent.get_child_count() - 1))
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = 0.0
		panel.offset_top = 0.0
		panel.offset_right = 0.0
		panel.offset_bottom = 0.0
	_workspace_dock_slots.erase(side)
	_workspace_floating_windows.erase(side)
	win.queue_free()
	_refresh_workspace_dock_toggle_row(side)


func _workspace_edge_snap_target(side: String) -> int:
	var main_pos: Vector2i = DisplayServer.window_get_position()
	var main_size: Vector2i = DisplayServer.window_get_size()
	if side == "left":
		return main_pos.x + 16
	return main_pos.x + main_size.x - 16


func _workspace_top_snap_y() -> int:
	var main_pos: Vector2i = DisplayServer.window_get_position()
	if _workspace_main_split == null:
		return main_pos.y + 80
	var rect: Rect2 = _workspace_main_split.get_global_rect()
	return int(round(main_pos.y + rect.position.y + 8.0))


func _workspace_content_rect_screen() -> Rect2i:
	var main_pos: Vector2i = DisplayServer.window_get_position()
	var main_size: Vector2i = DisplayServer.window_get_size()
	if _workspace_main_split == null:
		return Rect2i(main_pos.x + 8, main_pos.y + 80, maxi(600, main_size.x - 16), maxi(320, main_size.y - 96))
	var rect: Rect2 = _workspace_main_split.get_global_rect()
	var x: int = int(round(main_pos.x + rect.position.x))
	var y: int = int(round(main_pos.y + rect.position.y))
	var w: int = int(round(rect.size.x))
	var h: int = int(round(rect.size.y))
	return Rect2i(x, y, maxi(300, w), maxi(240, h))


func _workspace_side_from_window(win: Window) -> String:
	for k in _workspace_floating_windows.keys():
		if _workspace_floating_windows[k] == win:
			return str(k)
	return ""


func _snap_window_to_zone(win: Window, zone: String) -> void:
	if win == null:
		return
	_suppress_auto_snap = true
	var main_pos: Vector2i = DisplayServer.window_get_position()
	var main_size: Vector2i = DisplayServer.window_get_size()
	var top_y: int = _workspace_top_snap_y()
	var workspace_side: String = _workspace_side_from_window(win)
	var is_workspace_panel: bool = workspace_side != ""
	var ws_rect: Rect2i = _workspace_content_rect_screen()
	match zone:
		"left":
			if is_workspace_panel:
				var panel_w: int = clampi(int(round(float(ws_rect.size.x) * 0.24)), 260, 420)
				win.position = Vector2i(ws_rect.position.x + 8, ws_rect.position.y + 8)
				win.size = Vector2i(panel_w, maxi(260, ws_rect.size.y - 16))
			else:
				win.position = Vector2i(main_pos.x + 16, top_y)
				win.size = Vector2i(maxi(340, int(main_size.x * 0.40)), maxi(300, main_size.y - 120))
		"right":
			if is_workspace_panel:
				var panel_w: int = clampi(int(round(float(ws_rect.size.x) * 0.24)), 260, 420)
				win.position = Vector2i(ws_rect.position.x + ws_rect.size.x - panel_w - 8, ws_rect.position.y + 8)
				win.size = Vector2i(panel_w, maxi(260, ws_rect.size.y - 16))
			else:
				var w: int = maxi(340, int(main_size.x * 0.40))
				win.position = Vector2i(main_pos.x + maxi(16, main_size.x - w - 16), top_y)
				win.size = Vector2i(w, maxi(300, main_size.y - 120))
		"top":
			if is_workspace_panel:
				win.position = Vector2i(ws_rect.position.x + 8, ws_rect.position.y + 8)
				win.size = Vector2i(maxi(420, ws_rect.size.x - 16), maxi(260, int(float(ws_rect.size.y) * 0.42)))
			else:
				win.position = Vector2i(main_pos.x + 16, top_y)
				win.size = Vector2i(maxi(480, main_size.x - 32), maxi(260, int(main_size.y * 0.45)))
		_:
			win.popup_centered()
	_suppress_auto_snap = false


func _on_auto_snap_window_moved(kind: String, key: Variant) -> void:
	if _suppress_auto_snap:
		return
	var win: Window = null
	var workspace_side: String = ""
	if kind == "view":
		var tab_idx: int = int(key)
		if _floating_views.has(tab_idx):
			win = _floating_views[tab_idx]
	elif kind == "workspace":
		workspace_side = str(key)
		if _workspace_floating_windows.has(workspace_side):
			win = _workspace_floating_windows[workspace_side]
	if win == null:
		_hide_snap_guide()
		return
	var main_pos: Vector2i = DisplayServer.window_get_position()
	var main_size: Vector2i = DisplayServer.window_get_size()
	var top_y: int = _workspace_top_snap_y()
	var left_d: int = absi(win.position.x - (main_pos.x + 16))
	var right_d: int = absi((win.position.x + win.size.x) - (main_pos.x + main_size.x - 16))
	var top_d: int = absi(win.position.y - top_y)
	var allow_top_snap: bool = kind == "view"
	var best: int = mini(left_d, right_d)
	if allow_top_snap:
		best = mini(best, top_d)
	if best > FLOAT_SNAP_THRESHOLD_PX:
		_hide_snap_guide()
		return
	var zone: String = "left"
	if right_d < left_d:
		zone = "right"
	if allow_top_snap and top_d < mini(left_d, right_d):
		zone = "top"
	if kind == "workspace":
		# En paneles laterales, acercar al borde lateral correspondiente los re-acopla.
		var edge_target: int = _workspace_edge_snap_target(workspace_side)
		var edge_dist: int = (
			absi(win.position.x - edge_target)
			if workspace_side == "left"
			else absi((win.position.x + win.size.x) - edge_target)
		)
		if edge_dist <= FLOAT_SNAP_THRESHOLD_PX:
			_redock_workspace_panel(workspace_side)
			_hide_snap_guide()
			return
	_show_snap_guide(zone)
	if best == left_d:
		_snap_window_to_zone(win, "left")
	elif best == right_d:
		_snap_window_to_zone(win, "right")
	elif allow_top_snap:
		_snap_window_to_zone(win, "top")
	_hide_snap_guide()


func _ensure_snap_guide_overlay() -> void:
	if _snap_guide_overlay != null:
		return
	var root: Control = get_node_or_null("UI/Root")
	if root == null:
		return
	_snap_guide_overlay = ColorRect.new()
	_snap_guide_overlay.name = "SnapGuideOverlay"
	_snap_guide_overlay.color = Color(0.22, 0.74, 0.97, 0.18)
	_snap_guide_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snap_guide_overlay.visible = false
	_snap_guide_overlay.z_index = 200
	root.add_child(_snap_guide_overlay)


func _show_snap_guide(zone: String) -> void:
	if _snap_guide_overlay == null:
		return
	_snap_guide_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_snap_guide_overlay.offset_left = 0.0
	_snap_guide_overlay.offset_top = 0.0
	_snap_guide_overlay.offset_right = 0.0
	_snap_guide_overlay.offset_bottom = 0.0
	match zone:
		"left":
			_snap_guide_overlay.anchor_right = 0.40
		"right":
			_snap_guide_overlay.anchor_left = 0.60
		"top":
			_snap_guide_overlay.anchor_bottom = 0.45
		_:
			pass
	_snap_guide_overlay.visible = true


func _hide_snap_guide() -> void:
	if _snap_guide_overlay != null:
		_snap_guide_overlay.visible = false


func _refresh_top_palette_controls() -> void:
	if _scale_2d_preset_option == null or _scale_2d_custom_spin == null:
		return
	var is_2d: bool = _active_view_tab != 0 and _view_state_by_tab.has(_active_view_tab)
	_scale_2d_preset_option.visible = is_2d
	_scale_2d_custom_spin.visible = false
	if not is_2d:
		return
	var row: Dictionary = _view_state_by_tab[_active_view_tab] as Dictionary
	var den_from_state: int = _denominator_from_scale_factor(float(row.get("scale_2d", 1.0)))
	var preset_idx: int = SCALE_2D_PRESETS.find(den_from_state)
	_scale_2d_custom_spin.value = float(den_from_state)
	if preset_idx >= 0:
		_scale_2d_preset_option.select(preset_idx)
		_scale_2d_custom_spin.visible = false
	else:
		_scale_2d_preset_option.select(_scale_2d_preset_option.item_count - 1)
		_scale_2d_custom_spin.visible = true
	if is_2d:
		_log_label.text = "Escala activa %d:%d" % [1, den_from_state]


func _on_workspace_scale_preset_selected(selected_idx: int) -> void:
	var target_tab: int = _view_tabs_bar.current_tab
	if target_tab != _active_view_tab:
		_on_view_tabs_changed(target_tab)
	if target_tab == 0 or not _view_state_by_tab.has(target_tab):
		return
	var custom_idx: int = SCALE_2D_PRESETS.size()
	if selected_idx == custom_idx:
		_scale_2d_custom_spin.visible = true
		_set_floating_2d_scale_factor(target_tab, _scale_factor_from_denominator(_scale_2d_custom_spin.value))
		return
	_scale_2d_custom_spin.visible = false
	var den: int = int(SCALE_2D_PRESETS[selected_idx])
	_set_floating_2d_scale_factor(target_tab, _scale_factor_from_denominator(den))


func _on_workspace_custom_den_changed(value: float) -> void:
	var target_tab: int = _view_tabs_bar.current_tab
	if target_tab != _active_view_tab:
		_on_view_tabs_changed(target_tab)
	if target_tab == 0 or not _view_state_by_tab.has(target_tab):
		return
	if _scale_2d_preset_option.selected != _scale_2d_preset_option.item_count - 1:
		return
	_set_floating_2d_scale_factor(target_tab, _scale_factor_from_denominator(value))


func _sync_mini_tabs_from_main() -> void:
	return


func _on_mini_view_tab_changed(tab: int) -> void:
	_view_tabs_bar.current_tab = tab
	_on_view_tabs_changed(tab)


func _on_visual_style_selected(idx: int) -> void:
	var md: Variant = _visual_style_option.get_item_metadata(idx)
	_visual_style_current = str(md)
	_apply_visual_style(_visual_style_current)


func _apply_visual_style(style_id: String) -> void:
	if _viewport_manager != null:
		_viewport_manager.set_debug_draw(
			Viewport.DEBUG_DRAW_WIREFRAME if style_id == VIS_STYLE_WIREFRAME else Viewport.DEBUG_DRAW_DISABLED
		)
	var env: Environment = _world_environment.environment
	if env == null:
		return
	match style_id:
		VIS_STYLE_CONTRAST:
			env.background_mode = Environment.BG_CLEAR_COLOR
			env.background_color = Color(0.06, 0.065, 0.08, 1.0)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.76, 0.80, 0.86, 1.0)
			env.ambient_light_energy = 0.62
			_light.light_energy = 1.22
			_grid.visible = false
		VIS_STYLE_WIREFRAME:
			_apply_environment_viewport_flat(true)
			_light.light_energy = 0.95
			_grid.visible = true
		_:
			var is_persp: bool = (
				is_instance_valid(_camera_rig) and _camera_rig.has_method("is_perspective_preset")
				and bool(_camera_rig.is_perspective_preset())
			)
			_apply_environment_viewport_flat(is_persp)
			_light.light_energy = 1.08
			_grid.visible = true


func _active_view_title() -> String:
	return _view_tabs_bar.get_tab_title(_view_tabs_bar.current_tab)


func _on_float_active_view_pressed() -> void:
	var idx: int = _view_tabs_bar.current_tab
	if _floating_views.has(idx):
		var existing: Window = _floating_views[idx]
		existing.grab_focus()
		return
	var win: Window = Window.new()
	win.title = "Vista flotante: %s" % _active_view_title()
	win.size = Vector2i(840, 520)
	win.unresizable = false
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.offset_left = 12.0
	vbox.offset_top = 12.0
	vbox.offset_right = -12.0
	vbox.offset_bottom = -12.0
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp_host: SubViewportContainer = SubViewportContainer.new()
	vp_host.stretch = true
	vp_host.custom_minimum_size = Vector2(0.0, 380.0)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.own_world_3d = false
	vp.world_3d = _subviewport.world_3d
	var floating_rig: OrbitRig = OrbitRig.new() as OrbitRig
	var floating_cam: Camera3D = Camera3D.new()
	floating_cam.name = "Camera3D"
	floating_rig.add_child(floating_cam)
	vp.add_child(floating_rig)
	vp_host.add_child(vp)
	vp_host.gui_input.connect(_on_floating_viewport_gui_input.bind(idx))
	vbox.add_child(vp_host)
	var row: HBoxContainer = HBoxContainer.new()
	var activate_btn: Button = Button.new()
	activate_btn.text = "Activar vista"
	activate_btn.pressed.connect(_on_activate_floating_view.bind(idx))
	row.add_child(activate_btn)
	var snap_left_btn: Button = Button.new()
	snap_left_btn.text = "Snap Izq"
	snap_left_btn.pressed.connect(_on_snap_floating_view.bind(idx, "left"))
	row.add_child(snap_left_btn)
	var snap_right_btn: Button = Button.new()
	snap_right_btn.text = "Snap Der"
	snap_right_btn.pressed.connect(_on_snap_floating_view.bind(idx, "right"))
	row.add_child(snap_right_btn)
	var snap_top_btn: Button = Button.new()
	snap_top_btn.text = "Snap Arriba"
	snap_top_btn.pressed.connect(_on_snap_floating_view.bind(idx, "top"))
	row.add_child(snap_top_btn)
	var close_btn: Button = Button.new()
	close_btn.text = "Acoplar"
	close_btn.pressed.connect(_on_close_floating_view.bind(idx))
	row.add_child(close_btn)
	var hint: Label = Label.new()
	hint.text = "Preview en vivo del viewport principal (base para desacople por vista)."
	row.add_child(hint)
	vbox.add_child(row)
	_apply_button_style(activate_btn, UI_ACCENT_BLUE)
	_apply_button_style(snap_left_btn, UI_ACCENT_BLUE)
	_apply_button_style(snap_right_btn, UI_ACCENT_BLUE)
	_apply_button_style(snap_top_btn, UI_ACCENT_BLUE)
	_apply_button_style(close_btn, UI_ACCENT_BLUE)
	_style_label(hint, UI_MUTED)
	win.add_child(vbox)
	win.close_requested.connect(_on_close_floating_view.bind(idx))
	add_child(win)
	_floating_views[idx] = win
	_floating_viewports[idx] = {
		"subviewport": vp,
		"camera": floating_cam,
		"rig": floating_rig,
		"host": vp_host,
	}
	win.popup_centered()
	_snap_window_to_zone(win, "right")
	_refresh_main_viewport_docked_state()
	call_deferred("_sync_floating_view_camera_from_tab_state", idx)


func _sync_floating_view_camera_from_tab_state(tab_idx: int) -> void:
	if not _floating_viewports.has(tab_idx) or not _view_state_by_tab.has(tab_idx):
		return
	var slot: Dictionary = _floating_viewports[tab_idx] as Dictionary
	var floating_rig: OrbitRig = slot.get("rig") as OrbitRig
	var floating_cam: Camera3D = slot.get("camera") as Camera3D
	if floating_rig == null or floating_cam == null:
		return
	if not floating_rig.is_inside_tree():
		return
	var row_state: Dictionary = _view_state_by_tab[tab_idx] as Dictionary
	var cam_state: Dictionary = row_state.get("camera", {}) as Dictionary
	if not cam_state.is_empty():
		floating_rig.apply_view_state(cam_state)
	var snap: Dictionary = row_state.get("camera_snapshot", {}) as Dictionary
	_apply_camera_snapshot_to_camera(floating_cam, snap)


func _on_snap_floating_view(tab_idx: int, zone: String) -> void:
	if not _floating_views.has(tab_idx):
		return
	var win: Window = _floating_views[tab_idx]
	_snap_window_to_zone(win, zone)


func _on_floating_viewport_gui_input(event: InputEvent, tab_idx: int) -> void:
	if not _floating_viewports.has(tab_idx):
		return
	var slot: Dictionary = _floating_viewports[tab_idx] as Dictionary
	var rig: OrbitRig = slot.get("rig") as OrbitRig
	if rig == null:
		return
	if rig.handle_viewport_gui_input(event):
		var row: Dictionary = _view_state_by_tab.get(tab_idx, {}) as Dictionary
		if not row.is_empty():
			row["camera"] = rig.capture_view_state()
			var cam: Camera3D = slot.get("camera") as Camera3D
			row["camera_snapshot"] = _capture_camera_snapshot_from(cam)
			_view_state_by_tab[tab_idx] = row


func _set_floating_2d_scale_factor(tab_idx: int, new_scale: float) -> void:
	if tab_idx == 0 or not _view_state_by_tab.has(tab_idx):
		return
	var row: Dictionary = _view_state_by_tab[tab_idx] as Dictionary
	var old_scale: float = maxf(0.0001, float(row.get("scale_2d", 1.0)))
	new_scale = clampf(float(new_scale), 0.05, 20.0)
	var cam_state: Dictionary = row.get("camera", {}) as Dictionary
	var dist: float = float(cam_state.get("distance", 14.0))
	cam_state["distance"] = clampf(dist * old_scale / new_scale, 2.0, 1200.0)
	row["camera"] = cam_state
	var snap: Dictionary = row.get("camera_snapshot", {}) as Dictionary
	if not snap.is_empty():
		var old_size: float = float(snap.get("size", 10.0))
		snap["size"] = maxf(2.0, old_size * old_scale / new_scale)
		row["camera_snapshot"] = snap
	row["scale_2d"] = new_scale
	_view_state_by_tab[tab_idx] = row
	if tab_idx == _active_view_tab:
		var rig: OrbitRig = _camera_rig as OrbitRig
		if rig != null and tab_idx != 0:
			var live_state: Dictionary = rig.capture_view_state()
			var live_dist: float = float(live_state.get("distance", 14.0))
			live_state["distance"] = clampf(live_dist * old_scale / new_scale, 2.0, 1200.0)
			rig.apply_view_state(live_state)
			row["camera"] = rig.capture_view_state()
			row["camera_snapshot"] = _capture_main_camera_snapshot()
			row["scale_2d"] = new_scale
			_view_state_by_tab[tab_idx] = row
		_apply_view_state_for_tab(tab_idx)
		var den: int = _denominator_from_scale_factor(new_scale)
		_log_label.text = "Escala aplicada en vista %s: 1:%d" % [_view_tabs_bar.get_tab_title(tab_idx), den]
		_save_active_view_state(tab_idx)
	_sync_floating_viewport_cameras()


func _denominator_from_scale_factor(scale_factor: float) -> int:
	var sf: float = maxf(0.0001, scale_factor)
	return int(round(100.0 / sf))


func _scale_factor_from_denominator(denominator: float) -> float:
	var den: float = maxf(1.0, denominator)
	return 100.0 / den


func _on_floating_2d_scale_preset_selected(selected_idx: int, tab_idx: int, custom_spin: SpinBox) -> void:
	var custom_idx: int = SCALE_2D_PRESETS.size()
	if selected_idx == custom_idx:
		custom_spin.visible = true
		_set_floating_2d_scale_factor(tab_idx, _scale_factor_from_denominator(custom_spin.value))
		return
	custom_spin.visible = false
	var den: int = int(SCALE_2D_PRESETS[selected_idx])
	_set_floating_2d_scale_factor(tab_idx, _scale_factor_from_denominator(den))


func _on_floating_2d_custom_den_changed(value: float, tab_idx: int) -> void:
	_set_floating_2d_scale_factor(tab_idx, _scale_factor_from_denominator(value))


func _on_activate_floating_view(tab_idx: int) -> void:
	_view_tabs_bar.current_tab = tab_idx
	_on_view_tabs_changed(tab_idx)


func _on_close_floating_view(tab_idx: int) -> void:
	if not _floating_views.has(tab_idx):
		return
	var win: Window = _floating_views[tab_idx]
	if _floating_viewports.has(tab_idx):
		var slot: Dictionary = _floating_viewports[tab_idx] as Dictionary
		var rig: OrbitRig = slot.get("rig") as OrbitRig
		var cam: Camera3D = slot.get("camera") as Camera3D
		if _view_state_by_tab.has(tab_idx):
			var row: Dictionary = _view_state_by_tab[tab_idx] as Dictionary
			if rig != null:
				row["camera"] = rig.capture_view_state()
			if cam != null:
				row["camera_snapshot"] = _capture_camera_snapshot_from(cam)
			_view_state_by_tab[tab_idx] = row
	_floating_views.erase(tab_idx)
	_floating_viewports.erase(tab_idx)
	win.queue_free()
	_refresh_main_viewport_docked_state()
	if tab_idx > 3:
		_close_view_tab(tab_idx)


func _close_floating_view(tab_idx: int) -> void:
	_on_close_floating_view(tab_idx)


func _on_dock_all_views_pressed() -> void:
	var keys: Array = _floating_views.keys()
	for k in keys:
		_on_close_floating_view(int(k))
	_refresh_main_viewport_docked_state()


func _refresh_main_viewport_docked_state() -> void:
	if _subviewport == null:
		return
	var active_is_floating: bool = _floating_views.has(_active_view_tab)
	if active_is_floating:
		_sync_main_subviewport_render_policy()
		_view_2d_placeholder.visible = true
		_view_2d_placeholder_title.text = "Vista activa desacoplada"
		_view_2d_placeholder_hint.text = (
			"La vista \"%s\" está en ventana flotante. "
			% _view_tabs_bar.get_tab_title(_active_view_tab)
			+ "Acóplala o activa otra pestaña para mostrarla aquí."
		)
		%NavGizmo.visible = false
		return
	_sync_main_subviewport_render_policy()
	_view_2d_placeholder.visible = false
	%NavGizmo.visible = _active_view_tab == 0


func _duplicate_active_view() -> void:
	var tab: int = _view_tabs_bar.current_tab
	if not _view_state_by_tab.has(tab):
		return
	_save_active_view_state(tab)
	var src: Dictionary = _view_state_by_tab[tab] as Dictionary
	var next_name: String = "%s copia %d" % [str(src.get("name", "Vista")), _view_name_seq]
	_view_name_seq += 1
	var new_tab: int = _view_tabs_bar.tab_count
	_view_tabs_bar.add_tab(next_name)
	var row: Dictionary = src.duplicate(true)
	row["name"] = next_name
	row["is_default"] = false
	_view_state_by_tab[new_tab] = row
	_view_tabs_bar.current_tab = new_tab
	_on_view_tabs_changed(new_tab)


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
		return
	var d: Dictionary = _view2d_defs[id] as Dictionary
	var preset: String = str(d.get("preset", "top"))
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


func _is_valid_occ_uv(uv: Vector2) -> bool:
	return not (is_inf(uv.x) or is_inf(uv.y) or is_nan(uv.x) or is_nan(uv.y))


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
	if _viewport_manager != null:
		_viewport_manager.apply_msaa(SubViewport.MSAA_4X)
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
		elif k.pressed and k.alt_pressed and not k.ctrl_pressed and not k.meta_pressed:
			if k.keycode == KEY_1:
				_switch_view_tab_keyboard(1)
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_2:
				_switch_view_tab_keyboard(2)
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_3:
				_switch_view_tab_keyboard(3)
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_4:
				_switch_view_tab_keyboard(0)
				get_viewport().set_input_as_handled()
		elif k.pressed and k.keycode == KEY_DELETE and _delete_wall_shortcut_allowed():
			_on_delete_wall_pressed()
			get_viewport().set_input_as_handled()
		elif k.pressed and k.ctrl_pressed and not k.shift_pressed and k.keycode == KEY_D:
			_duplicate_active_view()
			get_viewport().set_input_as_handled()
		elif k.pressed and k.ctrl_pressed and not k.shift_pressed and k.keycode == KEY_W:
			_on_delete_view2d_pressed()
			get_viewport().set_input_as_handled()
		elif k.pressed and k.keycode == KEY_ESCAPE and _wall_tool.is_active():
			_cancel_wall_tool_with_esc()
			get_viewport().set_input_as_handled()
		elif k.pressed and k.keycode == KEY_TAB and k.alt_pressed and not k.ctrl_pressed and not k.meta_pressed:
			var dir: int = -1 if k.shift_pressed else 1
			if _select_wall_by_keyboard_step(dir):
				get_viewport().set_input_as_handled()
		elif k.pressed and k.keycode == KEY_W and not k.ctrl_pressed and not k.alt_pressed and not k.meta_pressed:
			_on_create_wall_pressed()
			get_viewport().set_input_as_handled()
		elif k.pressed and k.keycode == KEY_E and not k.ctrl_pressed and not k.alt_pressed and not k.meta_pressed:
			if _is_edit_mode_active():
				_exit_edit_mode("Modo edición: cerrado")
			else:
				var selected_guid: String = _project_view.selected_guid()
				if selected_guid != "":
					_enter_edit_mode(selected_guid)
			get_viewport().set_input_as_handled()
		elif (k.pressed or k.echo) and _wall_tool.is_active() and _handle_wall_keyboard_input(k):
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


func _switch_view_tab_keyboard(tab: int) -> void:
	_view_tabs_bar.current_tab = tab
	_on_view_tabs_changed(tab)
	var title: String = _view_tabs_bar.get_tab_title(tab)
	_log_label.text = "Vista activa (teclado): %s" % title


func _activate_wall_stable_2d_mode_if_needed() -> void:
	if not USE_OCC_2D_VIEWS or _active_view_tab == 0:
		return
	if _view2d_mode_before_wall == "":
		_view2d_mode_before_wall = _view2d_render_mode
	if _view2d_render_mode != VIEW2D_MODE_ORTHO:
		_view2d_render_mode = VIEW2D_MODE_ORTHO
		_update_view2d_mode_button_text()
		var preset: String = _tab_to_preset(_active_view_tab)
		var id: String = _find_view2d_id_by_preset(preset)
		if id != "":
			_render_view2d_for_id(id)


func _restore_view2d_mode_after_wall() -> void:
	if _view2d_mode_before_wall == "":
		return
	_view2d_render_mode = _view2d_mode_before_wall
	_view2d_mode_before_wall = ""
	_update_view2d_mode_button_text()
	if USE_OCC_2D_VIEWS and _active_view_tab != 0:
		var preset: String = _tab_to_preset(_active_view_tab)
		var id: String = _find_view2d_id_by_preset(preset)
		if id != "":
			_render_view2d_for_id(id)


func _wall_guids_sorted() -> Array:
	var guids: Array = []
	for guid in _wall_tree_items.keys():
		guids.append(str(guid))
	guids.sort()
	return guids


func _select_wall_by_keyboard_step(step: int) -> bool:
	var guids: Array = _wall_guids_sorted()
	if guids.is_empty():
		return false
	var current_guid: String = _project_view.selected_guid()
	var idx: int = guids.find(current_guid)
	if idx < 0:
		idx = 0 if step >= 0 else guids.size() - 1
	else:
		idx = posmod(idx + step, guids.size())
	var guid: String = str(guids[idx])
	_project_view.set_selection(guid)
	_sync_tree_selection(guid)
	if _is_edit_mode_active() and guid != _edit_mode_guid:
		_exit_edit_mode("")
	_refresh_properties_panel()
	_log_label.text = "Selección (teclado): %s" % guid
	return true


func _init_keyboard_wall_cursor_if_needed() -> void:
	if _kb_wall_cursor_ready:
		return
	var ref := Vector2.ZERO
	if _wall_tool != null and _wall_tool.has_method("get_chain_floor_reference_xy"):
		ref = _wall_tool.call("get_chain_floor_reference_xy") as Vector2
	_kb_wall_cursor_world = Vector3(ref.x, ref.y, BASE_STOREY_ELEVATION_M)
	_kb_wall_cursor_ready = true
	_wall_tool.handle_viewport_motion_world_floor(_kb_wall_cursor_world)


func _handle_wall_keyboard_input(k: InputEventKey) -> bool:
	var step: float = KB_WALL_STEP_COARSE_M if k.shift_pressed else KB_WALL_STEP_FINE_M
	if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		_init_keyboard_wall_cursor_if_needed()
		_wall_tool.handle_viewport_click_world_floor(_kb_wall_cursor_world)
		_log_label.text = "Crear muro (teclado): punto confirmado (Enter). Flechas mueven cursor."
		return true
	if k.keycode == KEY_BACKSPACE:
		_wall_tool.reset_draft()
		_kb_wall_cursor_ready = false
		_log_label.text = "Crear muro (teclado): trazo reiniciado."
		return true
	if (
		k.keycode != KEY_UP
		and k.keycode != KEY_DOWN
		and k.keycode != KEY_LEFT
		and k.keycode != KEY_RIGHT
	):
		return false
	_init_keyboard_wall_cursor_if_needed()
	match k.keycode:
		KEY_UP:
			_kb_wall_cursor_world.y += step
		KEY_DOWN:
			_kb_wall_cursor_world.y -= step
		KEY_LEFT:
			_kb_wall_cursor_world.x -= step
		KEY_RIGHT:
			_kb_wall_cursor_world.x += step
	_wall_tool.handle_viewport_motion_world_floor(_kb_wall_cursor_world)
	_log_label.text = (
		"Cursor muro (teclado): X=%.2f Y=%.2f | paso %.2fm (%s)"
		% [
			_kb_wall_cursor_world.x,
			_kb_wall_cursor_world.y,
			step,
			"Shift" if k.shift_pressed else "fino",
		]
	)
	return true


func _adjust_active_view_cut(delta_m: float) -> void:
	if not _view_state_by_tab.has(_active_view_tab):
		return
	var row: Dictionary = _view_state_by_tab[_active_view_tab] as Dictionary
	var preset: String = str(row.get("preset", _preset_for_tab(_active_view_tab)))
	var vr: Dictionary = row.get("view_range", _default_view_range_for_preset(preset)) as Dictionary
	var cut: float = float(vr.get("cut_plane_m", DEFAULT_PLAN_CUT_M))
	var bottom: float = float(vr.get("bottom_m", DEFAULT_PLAN_BOTTOM_M))
	var top: float = float(vr.get("top_m", DEFAULT_PLAN_TOP_M))
	cut = clampf(cut + delta_m, bottom, top)
	vr["cut_plane_m"] = cut
	row["view_range"] = vr
	_view_state_by_tab[_active_view_tab] = row
	_refresh_workspace_hud()
	_log_label.text = "Rango de vista (%s): corte %.2f m (PgUp/PgDn)." % [str(row.get("name", preset)), cut]


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


func _refresh_ribbon_compact_mode() -> void:
	if _ribbon == null or _ribbon_body == null:
		return
	# Mantener cinta siempre visible (preferencia de workspace tipo Revit).
	_ribbon_body.visible = true
	_ribbon.custom_minimum_size = Vector2(0.0, 118.0)


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
	var tab: int = _create_or_reuse_view_tab(label, preset, _default_view_range_for_preset(preset), false)
	_view_tabs_bar.current_tab = tab
	_on_view_tabs_changed(tab)
	_log_label.text = "Vista 2D activa: %s" % label


func _on_add_view2d_pressed() -> void:
	var preset: String = _tab_to_preset(_active_view_tab)
	if preset == "persp":
		preset = "top"
	var label: String = "Planta Nivel %02d" % _view_name_seq if preset == "top" else "Sección %d" % _view_name_seq
	_view_name_seq += 1
	var id: String = _register_view2d_tree_item(label, preset)
	if _view2d_items.has(id):
		var it: TreeItem = _view2d_items[id] as TreeItem
		it.select(0)
		_project_tree.scroll_to_item(it)
	_activate_view2d_from_tree(id)


func _on_delete_view2d_pressed() -> void:
	var tab: int = _view_tabs_bar.current_tab
	_close_view_tab(tab)


func _close_view_tab(tab: int) -> void:
	if tab <= 3:
		_log_label.text = "Las vistas base no se eliminan."
		return
	if not _view_state_by_tab.has(tab):
		return
	if _floating_views.has(tab):
		var win: Window = _floating_views[tab]
		_floating_views.erase(tab)
		_floating_viewports.erase(tab)
		win.queue_free()
	_view_state_by_tab.erase(tab)
	_view_tabs_bar.remove_tab(tab)
	var remapped: Dictionary = {}
	for k in _view_state_by_tab.keys():
		var idx: int = int(k)
		remapped[idx if idx < tab else idx - 1] = _view_state_by_tab[k]
	_view_state_by_tab = remapped
	_view_tabs_bar.current_tab = 0
	_on_view_tabs_changed(0)
	_log_label.text = "Vista cerrada."


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
		_kb_wall_cursor_ready = false
		_restore_view2d_mode_after_wall()
		_set_wall_trace_mode(false)
		_project_view.clear_selection()
		_exit_edit_mode("")
		_refresh_properties_panel()
		_log_label.text = "Crear muro: herramienta cerrada."
		_refresh_ribbon_compact_mode()
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
	_kb_wall_cursor_ready = false
	_activate_wall_stable_2d_mode_if_needed()
	_set_wall_trace_mode(true)
	_log_label.text = (
		"Crear muro: primer trazo P1+P2; los siguientes salen solo con P2 desde el último extremo "
		+ "(Alt+clic = nuevo P1). Teclado: flechas mueven, Enter confirma, Shift acelera, Backspace reinicia. "
		+ "Global: W muro, E editar, Alt+Tab siguiente muro, Alt+Shift+Tab anterior, Alt+1/2/3/4 cambia vista."
	)
	_refresh_ribbon_compact_mode()


func _on_push_pull_pressed() -> void:
	if _push_pull_tool.is_active():
		_push_pull_tool.deactivate()
		_refresh_properties_panel()
		_log_label.text = "Push/Pull: cancelado"
		_refresh_ribbon_compact_mode()
		return
	if not _is_edit_mode_active():
		_log_label.text = "Entra en modo edición para usar Push/Pull."
		return
	_wall_tool.deactivate()
	_restore_view2d_mode_after_wall()
	_set_wall_trace_mode(false)
	_project_view.set_selection(_edit_mode_guid)
	_refresh_properties_panel()
	_push_pull_tool.activate(_edit_mode_guid)
	_refresh_properties_panel()
	_log_label.text = "Push/Pull: elige una cara del elemento en edición."
	_refresh_ribbon_compact_mode()


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
	var in_occ_2d: bool = USE_OCC_2D_VIEWS and _active_view_tab != 0 and _view2d_render_mode != VIEW2D_MODE_ORTHO
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
				if _is_valid_occ_uv(uv_mm):
					_has_last_valid_occ_uv = true
					_last_valid_occ_uv = uv_mm
					var pwm: Vector3 = _occ_uv_to_floor_point_world(uv_mm)
					_wall_tool.handle_viewport_motion_world_floor(pwm)
				else:
					# En OCC 2D no degradamos a proyección 3D para evitar jitter
					# por desalineación de coordenadas entre backends gráficos.
					if _has_last_valid_occ_uv:
						var pwm_last: Vector3 = _occ_uv_to_floor_point_world(_last_valid_occ_uv)
						_wall_tool.handle_viewport_motion_world_floor(pwm_last)
						return
					var pos_fallback_m: Vector2 = _subviewport.get_mouse_position()
					if in_occ_2d and _view_2d_preview.has_method("to_snapshot_space"):
						pos_fallback_m = _view_2d_preview.call("to_snapshot_space", mm.position)
					_wall_tool.handle_viewport_motion(pos_fallback_m)
					return
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
				if _is_valid_occ_uv(uv_cl):
					_has_last_valid_occ_uv = true
					_last_valid_occ_uv = uv_cl
					var pwc: Vector3 = _occ_uv_to_floor_point_world(uv_cl)
					_wall_tool.handle_viewport_click_world_floor(pwc)
				else:
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
	_kb_wall_cursor_ready = false
	_restore_view2d_mode_after_wall()
	_set_wall_trace_mode(false)
	_project_view.clear_selection()
	_exit_edit_mode("")
	_refresh_properties_panel()
	_log_label.text = "Crear muro: cancelado (Esc)."
	_refresh_ribbon_compact_mode()


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
	_restore_view2d_mode_after_wall()
	_push_pull_tool.deactivate()
	_edit_mode_guid = guid
	_project_view.set_selection(guid)
	_project_view.set_edit_target(guid)
	_sync_tree_selection(guid)
	_refresh_properties_panel()
	_log_label.text = "Modo edición: %s. Usa Push/Pull o Esc para salir." % guid
	_refresh_ribbon_compact_mode()


func _exit_edit_mode(message: String) -> void:
	if _edit_mode_guid == "":
		return
	_edit_mode_guid = ""
	_push_pull_tool.deactivate()
	_project_view.clear_edit_target()
	_refresh_properties_panel()
	if message != "":
		_log_label.text = message
	_refresh_ribbon_compact_mode()


func _is_edit_mode_active() -> bool:
	return _edit_mode_guid != ""
