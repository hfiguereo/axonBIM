# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends "res://addons/gut/test.gd"

## Tests GUT del autoload RpcClient.
##
## Se ejecutan en CI solo cuando el addon GUT esta instalado
## (ver .github/workflows/ci.yml job `godot-tests`, condicional a
## hashFiles('frontend/addons/gut/**') != '').
##
## El backend real se lanza como subproceso antes de correr estos tests
## usando `scripts/dev/run_dev.sh`, y el puerto TCP se pasa por env
## `AXONBIM_RPC_PORT`.


func test_client_has_expected_api() -> void:
	assert_not_null(RpcClient)
	assert_true(RpcClient.has_method("call_rpc"))
	assert_true(RpcClient.has_method("notify_rpc"))
	assert_true(RpcClient.has_signal("connected"))
	assert_true(RpcClient.has_signal("disconnected"))
	assert_true(RpcClient.has_signal("notification_received"))


func test_axon_logger_levels_accept_all_severities() -> void:
	AxonLogger.debug("debug test")
	AxonLogger.info("info test")
	AxonLogger.warn("warn test")
	assert_true(true)


func test_ping_roundtrip_when_backend_running() -> void:
	if not RpcClient.is_connected_to_backend():
		pending("Backend RPC no esta conectado (requiere AXONBIM_RPC_PORT)")
		return
	var resp: Dictionary = await RpcClient.call_rpc("system.ping", {})
	assert_true(resp.get("ok"), "RPC fallo: %s" % str(resp))
	assert_true(resp["result"].get("pong"))
