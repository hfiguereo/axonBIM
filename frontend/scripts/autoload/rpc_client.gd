# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Cliente JSON-RPC 2.0 sobre TCP loopback al backend Python.
##
## Transporte: TCP en lugar de socket Unix porque Godot 4.x no expone
## `StreamPeerUnix` de forma nativa. El backend Python escucha en ambos
## transportes simultaneamente; Godot usa TCP y los tests/CLI usan Unix.
##
## Uso:
##     var resp: Dictionary = await RpcClient.call_rpc("system.ping", {})
##     if resp.get("ok"):
##         print(resp["result"])

signal connected
signal disconnected
signal notification_received(method: String, params: Dictionary)
# Uso interno: se emite cuando llega cualquier respuesta; los consumidores
# filtran por id.
signal response_arrived(id: int, response: Dictionary)

const DEFAULT_HOST: String = "127.0.0.1"
const DEFAULT_PORT: int = 0  # 0 => lee de env AXONBIM_RPC_PORT o de argumentos
const DEFAULT_TIMEOUT_MS: int = 10000
const POLL_INTERVAL_MS: int = 16  # ~60Hz
const MAX_BODY_BYTES: int = 64 * 1024 * 1024
const RECONNECT_INITIAL_DELAY_MS: int = 500
const RECONNECT_MAX_DELAY_MS: int = 10000

var _stream: StreamPeerTCP = StreamPeerTCP.new()
var _buffer: PackedByteArray = PackedByteArray()
var _next_id: int = 0
var _is_connected: bool = false
var _host: String = DEFAULT_HOST
var _port: int = DEFAULT_PORT
var _reconnect_enabled: bool = true
var _reconnect_delay_ms: int = RECONNECT_INITIAL_DELAY_MS
var _reconnect_at_ms: int = 0


func _ready() -> void:
	set_process(true)
	_host = _resolve_host()
	_port = _resolve_port()
	if _port > 0:
		_connect_to_backend()
	else:
		Logger.warn(
			(
				"RpcClient: no hay puerto TCP configurado (env AXONBIM_RPC_PORT). "
				+ "Pasale --tcp-port al backend y reinicia."
			)
		)


## Cierra el TCP ordenadamente al salir del editor o del juego.
##
## Sin esto, ``StreamPeerTCP`` puede seguir activo mientras Vulkan y el
## driver destruyen el contexto; en Linux eso a veces dispara el dialogo de
## "cierre inesperado" aunque no haya bug en la logica del proyecto.
func _exit_tree() -> void:
	_reconnect_enabled = false
	set_process(false)
	var status: int = _stream.get_status()
	if status != StreamPeerTCP.STATUS_NONE:
		_stream.disconnect_from_host()
	_is_connected = false
	_buffer = PackedByteArray()


func is_connected_to_backend() -> bool:
	return _is_connected


## Llama un metodo RPC y espera su respuesta.
##
## Devuelve un Dictionary:
##   {"ok": true, "result": Dictionary} si exito.
##   {"ok": false, "error": {"code": int, "message": String, "data": Variant}} si error.
##   {"ok": false, "error": {"code": -32005, "message": "timeout"}} si no llego a tiempo.
func call_rpc(
	method: String, params: Dictionary = {}, timeout_ms: int = DEFAULT_TIMEOUT_MS
) -> Dictionary:
	if not _is_connected:
		return _timeout_like_error(-32099, "backend no conectado")

	_next_id += 1
	var request_id: int = _next_id
	var payload: Dictionary = {
		"jsonrpc": "2.0",
		"id": request_id,
		"method": method,
		"params": params,
	}
	_send_framed(JSON.stringify(payload))

	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while true:
		var remaining: int = deadline - Time.get_ticks_msec()
		if remaining <= 0:
			return _timeout_like_error(-32005, "timeout")
		var args: Array = await response_arrived
		var got_id: int = args[0]
		var resp: Dictionary = args[1]
		if got_id == request_id:
			return _wrap_response(resp)
	return _timeout_like_error(-32603, "unreachable")


## Envia una notificacion (sin id, sin respuesta esperada).
func notify_rpc(method: String, params: Dictionary = {}) -> void:
	if not _is_connected:
		Logger.warn("RpcClient.notify_rpc('%s') sin conexion activa" % method)
		return
	var payload: Dictionary = {"jsonrpc": "2.0", "method": method, "params": params}
	_send_framed(JSON.stringify(payload))


func _process(_delta: float) -> void:
	_stream.poll()
	var status: int = _stream.get_status()

	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not _is_connected:
			_is_connected = true
			_reconnect_delay_ms = RECONNECT_INITIAL_DELAY_MS
			Logger.info("RpcClient conectado a %s:%d" % [_host, _port])
			connected.emit()
		_drain_available_bytes()
		_consume_buffer()
	elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		if _is_connected:
			_is_connected = false
			Logger.warn("RpcClient: conexion con backend perdida")
			disconnected.emit()
		_try_reconnect()


func _try_reconnect() -> void:
	if not _reconnect_enabled or _port <= 0:
		return
	var now: int = Time.get_ticks_msec()
	if _reconnect_at_ms == 0:
		_reconnect_at_ms = now + _reconnect_delay_ms
		return
	if now < _reconnect_at_ms:
		return
	_reconnect_at_ms = 0
	_reconnect_delay_ms = mini(_reconnect_delay_ms * 2, RECONNECT_MAX_DELAY_MS)
	_stream = StreamPeerTCP.new()
	_buffer = PackedByteArray()
	_connect_to_backend()


func _drain_available_bytes() -> void:
	var available: int = _stream.get_available_bytes()
	if available <= 0:
		return
	var got: Array = _stream.get_data(available)
	var err: int = got[0]
	if err != OK:
		Logger.error("RpcClient: get_data fallo con codigo %d" % err)
		return
	_buffer.append_array(got[1])


func _consume_buffer() -> void:
	while true:
		var header_end: int = _find_header_terminator(_buffer)
		if header_end < 0:
			return
		var header_text: String = _buffer.slice(0, header_end).get_string_from_ascii()
		var content_length: int = _parse_content_length(header_text)
		if content_length < 0:
			Logger.error("RpcClient: header sin Content-Length valido")
			_buffer = PackedByteArray()
			return
		if content_length > MAX_BODY_BYTES:
			Logger.error("RpcClient: Content-Length excesivo (%d)" % content_length)
			_buffer = PackedByteArray()
			return

		var body_start: int = header_end + 4  # \r\n\r\n
		if _buffer.size() < body_start + content_length:
			return

		var body: PackedByteArray = _buffer.slice(body_start, body_start + content_length)
		_buffer = _buffer.slice(body_start + content_length, _buffer.size())

		_handle_body(body.get_string_from_utf8())


func _handle_body(text: String) -> void:
	var parser: JSON = JSON.new()
	var err: int = parser.parse(text)
	if err != OK:
		Logger.error("RpcClient: JSON del backend invalido en linea %d" % parser.get_error_line())
		return
	var payload = parser.data
	if typeof(payload) != TYPE_DICTIONARY:
		Logger.error("RpcClient: respuesta no-objeto del backend")
		return
	var dict: Dictionary = payload
	if dict.has("id") and dict["id"] != null:
		var id_val: Variant = dict["id"]
		if typeof(id_val) != TYPE_INT and typeof(id_val) != TYPE_FLOAT:
			Logger.error("RpcClient: id no numerico en respuesta")
			return
		response_arrived.emit(int(id_val), dict)
	else:
		var method: String = dict.get("method", "")
		var params: Dictionary = dict.get("params", {})
		_handle_builtin_notification(method, params)
		notification_received.emit(method, params)


func _handle_builtin_notification(method: String, params: Dictionary) -> void:
	if method == "system.warning":
		Logger.warn("backend: %s" % str(params.get("message", params)))
	elif method == "system.info":
		Logger.info("backend: %s" % str(params.get("message", params)))


func _send_framed(text: String) -> void:
	var body: PackedByteArray = text.to_utf8_buffer()
	var header: PackedByteArray = ("Content-Length: %d\r\n\r\n" % body.size()).to_ascii_buffer()
	_stream.put_data(header)
	_stream.put_data(body)


func _connect_to_backend() -> void:
	var err: int = _stream.connect_to_host(_host, _port)
	if err != OK:
		Logger.error("RpcClient: connect_to_host %s:%d fallo (%d)" % [_host, _port, err])


func _resolve_host() -> String:
	var env: String = OS.get_environment("AXONBIM_RPC_HOST")
	return env if env != "" else DEFAULT_HOST


func _resolve_port() -> int:
	var env: String = OS.get_environment("AXONBIM_RPC_PORT")
	if env != "":
		return int(env)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rpc-port="):
			return int(arg.split("=")[1])
	return DEFAULT_PORT


func _find_header_terminator(buf: PackedByteArray) -> int:
	if buf.size() < 4:
		return -1
	for i in range(0, buf.size() - 3):
		if buf[i] == 13 and buf[i + 1] == 10 and buf[i + 2] == 13 and buf[i + 3] == 10:
			return i
	return -1


func _parse_content_length(headers: String) -> int:
	for line in headers.split("\r\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.to_lower().begins_with("content-length:"):
			var value: String = trimmed.substr(len("content-length:")).strip_edges()
			if value.is_valid_int():
				return int(value)
			return -1
	return -1


func _wrap_response(resp: Dictionary) -> Dictionary:
	if resp.has("error"):
		return {"ok": false, "error": resp["error"]}
	return {"ok": true, "result": resp.get("result", {})}


func _timeout_like_error(code: int, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}
