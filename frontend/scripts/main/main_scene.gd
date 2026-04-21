# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Escena raiz de AxonBIM (Sprint 1.4).
##
## Integra:
## - Viewport 3D con camara orbital y grid en Z=0.
## - Toolbar con "Ping backend" y "Crear muro".
## - Herramienta de creacion de muros.
## - Labels de estado de conexion y log de operaciones.

const CreateWallTool := preload("res://scripts/tools/create_wall_tool.gd")

var _wall_tool: Node

@onready var _ping_button: Button = %PingButton
@onready var _wall_button: Button = %CreateWallButton
@onready var _save_button: Button = %SaveButton
@onready var _status_label: Label = %StatusLabel
@onready var _rtt_label: Label = %RttLabel
@onready var _log_label: Label = %LogLabel
@onready var _camera: Camera3D = %Camera3D
@onready var _project_view: AxonProjectView = %ProjectView


func _ready() -> void:
	Logger.info("AxonBIM frontend iniciado (Sprint 1.4).")

	_wall_tool = CreateWallTool.new()
	add_child(_wall_tool)
	_wall_tool.setup(_camera, _project_view)
	_wall_tool.wall_created.connect(_on_wall_created)
	_wall_tool.tool_cancelled.connect(_on_wall_tool_idle)
	_wall_tool.wall_submit_finished.connect(_on_wall_tool_idle)

	RpcClient.connected.connect(_on_rpc_connected)
	RpcClient.disconnected.connect(_on_rpc_disconnected)
	_ping_button.pressed.connect(_on_ping_pressed)
	_wall_button.pressed.connect(_on_create_wall_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_project_view.viewport_left_click.connect(_on_project_view_left_click)

	_refresh_status()


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
		_project_view.set_wall_clicks_enabled(false)
		_log_label.text = "Crear muro: cancelado"
		return
	_wall_tool.activate()
	_project_view.set_wall_clicks_enabled(true)
	_log_label.text = "Crea muro: clickea P1 luego P2 en el viewport"


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


func _on_project_view_left_click(viewport_position: Vector2) -> void:
	if not _wall_tool.is_active():
		return
	_wall_tool.handle_viewport_click(viewport_position)


func _on_wall_tool_idle() -> void:
	_project_view.set_wall_clicks_enabled(false)


func _on_wall_created(guid: String) -> void:
	_log_label.text = "Muro creado: %s (total=%d)" % [guid, _project_view.entity_count()]
