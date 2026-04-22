# Registro de fallos de simulacion

## 2026-04-22 - Microtarea 5 (Push/Pull RPC smoke)

- **Comando:** `godot --headless --path frontend -s res://scripts/dev/push_pull_rpc_smoke.gd`
- **Resultado:** FAIL (compilacion)
- **Evidencia:**
  - `Compile Error: Identifier not found: RpcClient`
  - `Failed to load script "res://scripts/dev/push_pull_rpc_smoke.gd"`
- **Causa probable:** el script de smoke no puede resolver el autoload global en ese contexto de ejecucion.
- **Accion correctiva:** instanciar `rpc_client.gd` dentro del smoke test y llamar el metodo sobre esa instancia.
- **Verificacion posterior (PASS):**
  - Comando: `godot --headless --path frontend -s res://scripts/dev/push_pull_rpc_smoke.gd`
  - Salida: `{"ok": false, "error": {"code": -32099, "message": "backend no conectado"}}`
  - Interpretacion: el request se construye y se procesa; el error corresponde al backend apagado.
