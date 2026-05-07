# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Servidor JSON-RPC mínimo (framing LSP) para métodos ``worker.*`` en Godot headless.
##
## Escucha en loopback; mismo formato de mensajes que el backend Python (ver
## ``docs/architecture/jsonrpc-protocol.md``). Un cliente a la vez por aceptación.

const MAX_BODY_BYTES: int = 64 * 1024 * 1024
const DEFAULT_PORT: int = 5800

var _server: TCPServer = TCPServer.new()
var _peer: StreamPeerTCP = null
var _buffer: PackedByteArray = PackedByteArray()


func _ready() -> void:
	var port: int = DEFAULT_PORT
	var env_port: String = OS.get_environment("AXONBIM_WORKER_PORT")
	if env_port.is_valid_int():
		port = int(env_port)
	var err: int = _server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("AxonBIM worker: listen falló (%d)" % err)
		get_tree().quit(1)
		return
	print("AxonBIM worker JSON-RPC en 127.0.0.1:%d" % port)
	set_process(true)


func _process(_delta: float) -> void:
	if _peer == null:
		if _server.is_connection_available():
			_peer = _server.take_connection()
			_buffer = PackedByteArray()
		return
	_peer.poll()
	var st: int = _peer.get_status()
	if st != StreamPeerTCP.STATUS_CONNECTED:
		_peer = null
		_buffer = PackedByteArray()
		return
	var avail: int = _peer.get_available_bytes()
	if avail <= 0:
		return
	var got: Array = _peer.get_data(avail)
	if int(got[0]) != OK:
		return
	_buffer.append_array(got[1])
	_consume_buffer()


func _consume_buffer() -> void:
	while true:
		var header_end: int = _find_header_terminator(_buffer)
		if header_end < 0:
			return
		var header_text: String = _buffer.slice(0, header_end).get_string_from_ascii()
		var content_length: int = _parse_content_length(header_text)
		if content_length < 0 or content_length > MAX_BODY_BYTES:
			_send_error(-32700, "Invalid framing", null)
			_buffer = PackedByteArray()
			return
		var body_start: int = header_end + 4
		if _buffer.size() < body_start + content_length:
			return
		var body: PackedByteArray = _buffer.slice(body_start, body_start + content_length)
		_buffer = _buffer.slice(body_start + content_length, _buffer.size())
		_handle_body(body.get_string_from_utf8())


func _handle_body(text: String) -> void:
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		_send_error(-32700, "Parse error", null)
		return
	var payload = parser.data
	if typeof(payload) != TYPE_DICTIONARY:
		_send_error(-32600, "Invalid request", null)
		return
	var dict: Dictionary = payload
	if not dict.has("jsonrpc") or str(dict["jsonrpc"]) != "2.0":
		_send_error(-32600, "Invalid request", null)
		return
	if not dict.has("id") or dict["id"] == null:
		return
	var id_val: Variant = dict["id"]
	if typeof(id_val) != TYPE_INT and typeof(id_val) != TYPE_FLOAT:
		_send_error(-32600, "Invalid id", null)
		return
	var req_id: int = int(id_val)
	var method: String = str(dict.get("method", ""))
	var params: Dictionary = dict.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		_send_error(-32602, "Invalid params", req_id)
		return
	var response: Dictionary = _dispatch(method, params, req_id)
	_send_framed(JSON.stringify(response))


func _dispatch(method: String, params: Dictionary, req_id: int) -> Dictionary:
	match method:
		"worker.ping":
			return {"jsonrpc": "2.0", "id": req_id, "result": {"pong": true, "engine": "Godot"}}
		"worker.aabb_intersects":
			var boxes: Variant = _parse_two_aabbs(params)
			if boxes == null:
				return {
					"jsonrpc": "2.0",
					"id": req_id,
					"error": {"code": -32602, "message": "Invalid params"},
				}
			var a: AABB = boxes[0]
			var b: AABB = boxes[1]
			return {"jsonrpc": "2.0", "id": req_id, "result": {"intersects": a.intersects(b)}}
		_:
			return {
				"jsonrpc": "2.0",
				"id": req_id,
				"error": {"code": -32601, "message": "Method not found: %s" % method},
			}


func _parse_two_aabbs(params: Dictionary) -> Variant:
	var amin: Variant = params.get("a_min", null)
	var amax: Variant = params.get("a_max", null)
	var bmin: Variant = params.get("b_min", null)
	var bmax: Variant = params.get("b_max", null)
	var a0: Vector3 = _vec3_from_json_array(amin)
	var a1: Vector3 = _vec3_from_json_array(amax)
	var b0: Vector3 = _vec3_from_json_array(bmin)
	var b1: Vector3 = _vec3_from_json_array(bmax)
	if not a0.is_finite() or not a1.is_finite() or not b0.is_finite() or not b1.is_finite():
		return null
	var aabb_a := AABB(a0, a1 - a0)
	var aabb_b := AABB(b0, b1 - b0)
	return [aabb_a, aabb_b]


func _vec3_from_json_array(v: Variant) -> Vector3:
	if typeof(v) != TYPE_ARRAY:
		return Vector3(INF, INF, INF)
	var arr: Array = v
	if arr.size() != 3:
		return Vector3(INF, INF, INF)
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _send_error(code: int, message: String, req_id: Variant) -> void:
	var err_obj: Dictionary = {"code": code, "message": message}
	var payload: Dictionary
	if req_id == null:
		payload = {"jsonrpc": "2.0", "error": err_obj}
	else:
		payload = {"jsonrpc": "2.0", "id": int(req_id), "error": err_obj}
	_send_framed(JSON.stringify(payload))


func _send_framed(text: String) -> void:
	if _peer == null:
		return
	var body: PackedByteArray = text.to_utf8_buffer()
	var header: PackedByteArray = ("Content-Length: %d\r\n\r\n" % body.size()).to_ascii_buffer()
	_peer.put_data(header)
	_peer.put_data(body)


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
			var value: String = trimmed.substr(15).strip_edges()
			if value.is_valid_int():
				return int(value)
			return -1
	return -1
