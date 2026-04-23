# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Escena raiz de AxonBIM (Fase 2 — UI cinta + Push/Pull + undo RPC).

const CreateWallTool := preload("res://scripts/tools/create_wall_tool.gd")
const PushPullTool := preload("res://scripts/tools/push_pull_tool.gd")

var _wall_tool: Node
var _push_pull_tool: Node
var _muros_tree_parent: TreeItem
var _wall_tree_items: Dictionary = {}  # guid -> TreeItem

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
@onready var _camera: Camera3D = $UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/SubViewport/World/Camera3D
@onready var _project_view: Node3D = (
	$UI/Root/Workspace/MainSplit/InnerSplit/ViewportContainer/SubViewport/World/ProjectView
)
@onready var _viewport_container: SubViewportContainer = $%ViewportContainer
@onready var _subviewport: SubViewport = $%SubViewport


func _ready() -> void:
	Logger.info("AxonBIM frontend iniciado (Fase 2 · UI cinta + acoples).")

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
	_viewport_container.gui_input.connect(_on_viewport_container_gui_input)
	_project_tree.item_selected.connect(_on_project_tree_item_selected)

	_build_project_tree()
	_refresh_status()
	_refresh_properties_panel()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and k.keycode == KEY_Z and k.ctrl_pressed and not k.shift_pressed:
			_do_undo_async()


func _do_undo_async() -> void:
	var resp: Dictionary = await RpcClient.call_rpc("history.undo", {})
	if not is_inside_tree():
		return
	if not resp.get("ok"):
		_log_label.text = "Undo: %s" % str(resp.get("error"))
		return
	var r: Dictionary = resp["result"] as Dictionary
	if not bool(r.get("applied", false)):
		_log_label.text = "Undo: %s" % str(r.get("reason", "nada"))
		return
	var guid: String = str(r.get("guid", ""))
	var mesh_dict: Dictionary = r.get("mesh", {}) as Dictionary
	if guid != "" and not mesh_dict.is_empty():
		_project_view.replace_entity_mesh(guid, mesh_dict)
		_project_view.set_selection(guid)
		_refresh_properties_panel()
	_log_label.text = "Undo aplicado."


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
		return
	_prop_guid_label.text = "GlobalId: %s" % guid
	_prop_type_label.text = "Tipo: IfcWall"
	_prop_dims_label.text = "Geometría: (detalle vía RPC en Fase 2)"


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
		_refresh_properties_panel()
		_log_label.text = "Crear muro: cancelado"
		return
	_push_pull_tool.deactivate()
	_project_view.clear_selection()
	_refresh_properties_panel()
	_wall_tool.activate()
	_log_label.text = "Crea muro: clickea P1 luego P2 en el viewport"


func _on_push_pull_pressed() -> void:
	if _push_pull_tool.is_active():
		_push_pull_tool.deactivate()
		_log_label.text = "Push/Pull: cancelado"
		return
	_wall_tool.deactivate()
	_project_view.clear_selection()
	_refresh_properties_panel()
	_push_pull_tool.activate()
	_log_label.text = "Push/Pull: clic en cara del muro."


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


func _on_viewport_container_gui_input(event: InputEvent) -> void:
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
				_sync_tree_selection(picked)
				_refresh_properties_panel()
				if picked != "":
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
