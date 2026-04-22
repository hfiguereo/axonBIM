# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends SceneTree

## Smoke E2E: Godot + backend real (TCP) para ``geom.extrude_face``.
##
## Requiere que el backend escuche en el puerto dado por ``AXONBIM_RPC_PORT``
## (y opcionalmente ``AXONBIM_RPC_HOST``). Sale 0 si la respuesta es exitosa.

const RpcClientNode := preload("res://scripts/autoload/rpc_client.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rpc: Node = RpcClientNode.new()
	root.add_child(rpc)

	var deadline_ms: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline_ms:
		if rpc.is_connected_to_backend():
			break
		await process_frame

	if not rpc.is_connected_to_backend():
		push_error("push_pull_rpc_e2e_smoke: backend no conectado a tiempo")
		quit(1)
		return

	var resp: Dictionary = await rpc.call_rpc(
		"geom.extrude_face", {"topo_id": "face.e2e", "vector": [0.15, 0.0, 0.0]}
	)
	print("push_pull_rpc_e2e_smoke response: ", resp)

	if not resp.get("ok", false):
		push_error("push_pull_rpc_e2e_smoke: RPC fallo")
		quit(1)
		return

	var result: Dictionary = resp.get("result", {})
	if not result.has("mesh") or not result.has("topo_map"):
		push_error("push_pull_rpc_e2e_smoke: result incompleto")
		quit(1)
		return

	print("push_pull_rpc_e2e_smoke: PASS")
	quit(0)
