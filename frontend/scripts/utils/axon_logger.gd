# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends RefCounted
class_name AxonLogger

## Logger estatico para scripts frontend sin dependencia de autoload.
##
## Evita colisiones de nombre con clases nativas y permite usar logging
## durante parse/headless aun cuando los autoloads no esten inicializados.

enum Level { DEBUG, INFO, WARN, ERROR }


static func debug(msg: String) -> void:
	if _min_level() <= Level.DEBUG:
		print("[DEBUG] ", msg)


static func info(msg: String) -> void:
	if _min_level() <= Level.INFO:
		print("[INFO ] ", msg)


static func warn(msg: String) -> void:
	if _min_level() <= Level.WARN:
		push_warning(msg)


static func error(msg: String) -> void:
	if _min_level() <= Level.ERROR:
		push_error(msg)


static func _min_level() -> int:
	var env: String = OS.get_environment("AXONBIM_LOG_LEVEL").to_upper()
	match env:
		"DEBUG":
			return Level.DEBUG
		"INFO":
			return Level.INFO
		"WARN", "WARNING":
			return Level.WARN
		"ERROR":
			return Level.ERROR
		_:
			return Level.INFO
