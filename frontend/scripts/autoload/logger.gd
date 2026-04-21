# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node

## Logger wrapper con niveles. Singleton autoload `Logger`.

enum Level { DEBUG, INFO, WARN, ERROR }

var min_level: int = Level.INFO


func _ready() -> void:
	var env: String = OS.get_environment("AXONBIM_LOG_LEVEL")
	if env != "":
		_set_level_from_string(env)


func _set_level_from_string(name: String) -> void:
	match name.to_upper():
		"DEBUG":
			min_level = Level.DEBUG
		"INFO":
			min_level = Level.INFO
		"WARN", "WARNING":
			min_level = Level.WARN
		"ERROR":
			min_level = Level.ERROR
		_:
			push_warning("Nivel de log desconocido: %s" % name)


func debug(msg: String) -> void:
	if min_level <= Level.DEBUG:
		print("[DEBUG] ", msg)


func info(msg: String) -> void:
	if min_level <= Level.INFO:
		print("[INFO ] ", msg)


func warn(msg: String) -> void:
	if min_level <= Level.WARN:
		push_warning(msg)


func error(msg: String) -> void:
	if min_level <= Level.ERROR:
		push_error(msg)
