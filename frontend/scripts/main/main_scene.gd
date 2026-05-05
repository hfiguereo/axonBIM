# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Escena raiz de AxonBIM (Fase 2 — UI cinta + Push/Pull + undo RPC).

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
const VIEWPORT_SKY_TOP: Color = Color(0.012, 0.039, 0.090, 1.0)
const VIEWPORT_SKY_HORIZON: Color = Color(0.055, 0.137, 0.210, 1.0)
const VIEWPORT_GROUND_HORIZON: Color = Color(0.045, 0.071, 0.094, 1.0)
const VIEWPORT_GROUND_BOTTOM: Color = Color(0.015, 0.019, 0.027, 1.0)

var _wall_tool: Node
var _push_pull_tool: Node
var _muros_tree_parent: TreeItem
var _wall_tree_items: Dictionary = {}  # guid -> TreeItem
var _edit_mode_guid: String = ""

@onready var _ribbon_tabs: TabBar = $%RibbonTabs
@onready var _ribbon_tools_inicio: Control = $%RibbonToolsInicio
@onready var _ribbon_tools_placeholder: Control = $%RibbonToolsPlaceholder
@onready var _ping_button: Button = $%PingButton
@onready var _wall_button: Button = $%CreateWallButton
@onready var _push_pull_button: Button = $%PushPullButton
@onready var _save_button: Button = $%SaveButton
@onready var _status_label: Label = $%StatusLabel
@onready var _rtt_label: Label = $%RttLabel
@onready var _log_label: Label = $%LogLabel
@onready var _project_tree: Tree = $%ProjectTree
@onready var _prop_guid_label: Label = $%PropGuidLabel
@onready var _prop_type_label: Label = $%PropTypeLabel
@onready var _prop_dims_label: Label = $%PropDimsLabel
@onready var _edit_mode_button: Button = $%EditModeButton
@onready var _push_pull_distance: SpinBox = $%PushPullDistanceSpin
@onready var _push_pull_apply_distance_button: Button = $%ApplyPushPullDistanceButton
@onready var _camera: Camera3D = %Camera3D
@onready var _project_view: Node3D = %ProjectView
@onready var _viewport_container: SubViewportContainer = $%ViewportContainer
@onready var _subviewport: SubViewport = $%SubViewport
@onready var _world_environment: WorldEnvironment = %WorldEnvironment
@onready var _grid: MeshInstance3D = %Grid
@onready var _light: DirectionalLight3D = %Light


func _ready() -> void:
	Logger.info("AxonBIM frontend iniciado (Fase 2 · UI cinta + acoples).")
	_apply_visual_polish()

	_ribbon_tabs.set_tab_title(0, "Inicio")
	_ribbon_tabs.set_tab_title(1, "Insertar")
	_ribbon_tabs.set_tab_title(2, "Vista")
	_ribbon_tabs.tab_changed.connect(_on_ribbon_tab_changed)
	_on_ribbon_tab_changed(_ribbon_tabs.current_tab)

	_wall_tool = CreateWallTool.new()
	add_child(_wall_tool)
	_wall_tool.setup(_camera, _project_view)
	_wall_tool.wall_created.connect(_on_wall_created)

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
	_edit_mode_button.pressed.connect(_on_edit_mode_button_pressed)
	_push_pull_apply_distance_button.pressed.connect(_on_push_pull_apply_distance_pressed)
	_viewport_container.gui_input.connect(_on_viewport_container_gui_input)
	_project_tree.item_selected.connect(_on_project_tree_item_selected)

	_build_project_tree()
	_refresh_status()
	_refresh_properties_panel()


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
	_apply_panel_style(_viewport_container, Color(0.020, 0.035, 0.055, 1.0), UI_ACCENT_BLUE, 10)
	_apply_button_style(_ping_button, UI_ACCENT_BLUE)
	_apply_button_style(_wall_button, UI_ACCENT_BLUE)
	_apply_button_style(_push_pull_button, UI_ACCENT_AMBER)
	_apply_button_style(_save_button, UI_ACCENT_BLUE)
	_apply_button_style(_edit_mode_button, UI_ACCENT_AMBER)
	_apply_button_style(_push_pull_apply_distance_button, UI_ACCENT_AMBER)
	_apply_spinbox_style(_push_pull_distance)
	_style_label($UI/Root/Ribbon/TitleBar/AppTitle, UI_TEXT)
	_style_label(_status_label, UI_TEXT)
	_style_label(_rtt_label, UI_MUTED)
	_style_label(_log_label, UI_TEXT)
	_style_label($UI/Root/Workspace/MainSplit/LeftDock/LeftDockHeader/LeftDockTitle, UI_TEXT)
	_style_label(
		$UI/Root/Workspace/MainSplit/InnerSplit/RightDock/RightDockHeader/RightDockTitle, UI_TEXT
	)
	_style_project_tree()


func _apply_viewport_polish() -> void:
	var env: Environment = _world_environment.environment
	if env == null:
		env = Environment.new()
		_world_environment.environment = env
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = VIEWPORT_SKY_TOP
	sky_material.sky_horizon_color = VIEWPORT_SKY_HORIZON
	sky_material.ground_horizon_color = VIEWPORT_GROUND_HORIZON
	sky_material.ground_bottom_color = VIEWPORT_GROUND_BOTTOM
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.08
	sky_material.sun_energy_multiplier = 0.35
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	_light.light_color = Color(0.780, 0.880, 1.0, 1.0)
	_light.light_energy = 1.35
	_grid.material_override = _grid_material()


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
	mat.albedo_color = Color(0.180, 0.320, 0.410, 0.34)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.060, 0.160, 0.230, 1.0)
	mat.emission_energy_multiplier = 0.28
	mat.roughness = 0.9
	return mat


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and k.keycode == KEY_Z and k.ctrl_pressed and k.shift_pressed:
			_do_redo_async()
		elif k.pressed and k.keycode == KEY_Z and k.ctrl_pressed:
			_do_undo_async()
		elif k.pressed and k.keycode == KEY_ESCAPE and _is_edit_mode_active():
			_exit_edit_mode("Modo edición: cerrado")


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


func _on_ribbon_tab_changed(tab: int) -> void:
	var inicio: bool = tab == 0
	_ribbon_tools_inicio.visible = inicio
	_ribbon_tools_placeholder.visible = not inicio


func _build_project_tree() -> void:
	_project_tree.clear()
	_wall_tree_items.clear()
	var hidden_root: TreeItem = _project_tree.create_item()
	var proyecto: TreeItem = _project_tree.create_item(hidden_root)
	proyecto.set_text(0, "Proyecto (sesión)")
	var vistas: TreeItem = _project_tree.create_item(proyecto)
	vistas.set_text(0, "Vistas")
	var v3d: TreeItem = _project_tree.create_item(vistas)
	v3d.set_text(0, "Vista 3D")
	v3d.set_metadata(0, "VIEW_3D")
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
		return
	_prop_guid_label.text = "GlobalId: %s" % guid
	_prop_type_label.text = "Tipo: IfcWall"
	_prop_dims_label.text = "Geometría: (detalle vía RPC en Fase 2)"
	_edit_mode_button.disabled = false
	_edit_mode_button.text = "Salir de edición" if _edit_mode_guid == guid else "Editar elemento"
	_push_pull_distance.editable = _is_edit_mode_active()
	_push_pull_apply_distance_button.disabled = not (
		_is_edit_mode_active() and _push_pull_tool.is_active()
	)


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
		_project_view.clear_selection()
		_exit_edit_mode("")
		_refresh_properties_panel()
		_log_label.text = "Crear muro: cancelado"
		return
	_push_pull_tool.deactivate()
	_project_view.clear_selection()
	_exit_edit_mode("")
	_refresh_properties_panel()
	_wall_tool.activate()
	_log_label.text = "Crea muro: clickea P1 luego P2 en el viewport"


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


func _on_push_pull_apply_distance_pressed() -> void:
	if not _push_pull_tool.is_active():
		_log_label.text = "Activa Push/Pull y fija una cara antes de aplicar distancia."
		return
	await _push_pull_tool.apply_numeric_distance(float(_push_pull_distance.value))
	_refresh_properties_panel()


func _on_viewport_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _push_pull_tool.is_active() and _push_pull_tool.is_selecting_face():
			var pos_m: Vector2 = _subviewport.get_mouse_position()
			_project_view.update_face_hover_at_screen(_camera, pos_m)
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var pos: Vector2 = _subviewport.get_mouse_position()
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


func _on_wall_created(guid: String) -> void:
	var item: TreeItem = _project_tree.create_item(_muros_tree_parent)
	var short_id: String = guid.substr(0, 8) if guid.length() >= 8 else guid
	item.set_text(0, "Muro %s…" % short_id)
	item.set_metadata(0, guid)
	_wall_tree_items[guid] = item
	item.select(0)
	_project_view.set_selection(guid)
	_refresh_properties_panel()
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
