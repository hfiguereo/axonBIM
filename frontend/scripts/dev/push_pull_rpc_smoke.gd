# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends SceneTree
const RpcClientNode := preload("res://scripts/autoload/rpc_client.gd")

## Smoke test del primer RPC de Push/Pull.
##
## Intenta enviar `geom.extrude_face` con payload valido. En este momento el
## backend puede responder error (metodo no implementado o sin conexion), lo cual
## tambien se considera evidencia valida de que el request se intenta.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rpc: Node = RpcClientNode.new()
	root.add_child(rpc)
	await process_frame

	var payload: Dictionary = {
		"topo_id": "preview.face.smoke",
		"vector": [0.2, 0.0, 0.0],
	}
	var resp: Dictionary = await rpc.call_rpc("geom.extrude_face", payload)
	print("push_pull_rpc_smoke response: ", resp)
	if resp.has("ok"):
		quit(0)
		return
	push_error("push_pull_rpc_smoke: respuesta invalida")
	quit(1)
