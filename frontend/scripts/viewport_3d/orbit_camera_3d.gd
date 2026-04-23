# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Camera3D

## Orbita alrededor de un pivote con boton medio + rueda para zoom.
##
## No usa clic izquierdo: reservado para herramientas (muro, push/pull) en
## ``ProjectView``. Boton medio: rotar; rueda: acercar/alejar.

@export var pivot: Vector3 = Vector3.ZERO
@export var yaw_sensitivity: float = 0.005
@export var pitch_sensitivity: float = 0.005
@export var zoom_sensitivity: float = 0.12
@export var min_distance: float = 2.0
@export var max_distance: float = 80.0

var _yaw: float = 0.0
var _pitch: float = 0.45
var _distance: float = 14.0


func _ready() -> void:
	var offset: Vector3 = global_position - pivot
	_distance = clampf(offset.length(), min_distance, max_distance)
	if _distance < 1e-4:
		_distance = 14.0
	_yaw = atan2(offset.x, offset.z)
	var horiz: float = sqrt(offset.x * offset.x + offset.z * offset.z)
	if horiz < 1e-6:
		_pitch = 0.45
	else:
		_pitch = clampf(atan2(offset.y, horiz), deg_to_rad(-85.0), deg_to_rad(85.0))
	_apply_orbit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			_yaw -= motion.relative.x * yaw_sensitivity
			_pitch -= motion.relative.y * pitch_sensitivity
			_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
			_apply_orbit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var btn: InputEventMouseButton = event
		if not btn.pressed:
			return
		if btn.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance * (1.0 - zoom_sensitivity), min_distance, max_distance)
			_apply_orbit()
			get_viewport().set_input_as_handled()
		elif btn.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance * (1.0 + zoom_sensitivity), min_distance, max_distance)
			_apply_orbit()
			get_viewport().set_input_as_handled()


func _apply_orbit() -> void:
	var cp: float = cos(_pitch)
	var dir: Vector3 = Vector3(cp * sin(_yaw), sin(_pitch), cp * cos(_yaw))
	global_position = pivot + dir * _distance
	look_at(pivot, Vector3.UP)
