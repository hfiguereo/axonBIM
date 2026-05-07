# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Facade delgada entre ``RpcClient`` y la UI: notificaciones y estado de transporte.
##
## Centraliza la forma en que las escenas suscriben eventos del backend sin
## acoplarse al parser JSON-RPC. Las señales de dominio se derivan aquí para
## mantener un único punto de normalización de ``params``.

signal backend_notification(method: String, params: Dictionary)
signal system_warning(message: String, level: String)
signal backend_info(message: String)
signal backend_transport_connected
signal backend_transport_disconnected


func _ready() -> void:
	RpcClient.notification_received.connect(_on_rpc_notification)
	RpcClient.connected.connect(_on_rpc_transport_connected)
	RpcClient.disconnected.connect(_on_rpc_transport_disconnected)


func _on_rpc_transport_connected() -> void:
	backend_transport_connected.emit()


func _on_rpc_transport_disconnected() -> void:
	backend_transport_disconnected.emit()


func _on_rpc_notification(method: String, params: Dictionary) -> void:
	backend_notification.emit(method, params)
	if method == "system.warning":
		system_warning.emit(str(params.get("message", "")), str(params.get("level", "warn")))
	elif method == "system.info":
		backend_info.emit(str(params.get("message", "")))
