# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node3D

## Orbita alrededor de ``global_position`` (pivote). Convención **Z arriba** (plano XY
## del suelo, igual que ``create_wall_tool``). ``Camera3D`` mira el origen local del rig
## con ``look_at(..., Vector3(0,0,1))``.
##
## Ratón: MMB=orbita, Mayús+MMB=pan, rueda=zoom. Trackpad: Alt+LMB=orbita,
## Mayús+LMB=pan, Ctrl/Cmd+LMB arrastre vertical=zoom. Pellizco: ``InputEventMagnifyGesture``.
##
## Presets **top** / **front** / **right** usan proyección **ortogonal**; al orbitar
## (MMB o Alt+LMB) se pasa a **perspectiva** conservando la dirección de vista.
##
## Al alternar entre ortogonales y perspectiva se emite ``viewport_projection_mode_changed``:
## el UI ajusta **fondo y ambiente** (ambos modo **color plano**; perspectiva = tono algo más claro).

signal viewport_projection_mode_changed(is_perspective: bool)

@onready var camera: Camera3D = $Camera3D

const PITCH_LIMIT: float = deg_to_rad(85.0)
const ORBIT_SENS: float = 0.005
const PAN_SENS: float = 0.0035
const MIN_DISTANCE: float = 0.8
const MAX_DISTANCE: float = 1200.0
const PERSP_FOV: float = 55.0
const ORTHO_SIZE_SCALE: float = 0.11
const ORTHO_FRAME_MARGIN: float = 1.20

var _yaw: float = TAU / 8.0
var _pitch: float = asin(1.0 / sqrt(3.0))
var _distance: float = 14.0
var _mmb_orbit: bool = false
var _mmb_pan: bool = false
var _view_preset: String = "persp"
var _last_perspective_mode_emitted: bool = true


func _ready() -> void:
	if not is_instance_valid(camera):
		push_error("OrbitCameraRig: falta nodo hijo Camera3D")
		return
	_apply()


func handle_viewport_gui_input(event: InputEvent) -> bool:
	if not is_instance_valid(camera):
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_mmb_pan = mb.shift_pressed
				_mmb_orbit = not mb.shift_pressed
				return true
			_mmb_orbit = false
			_mmb_pan = false
			return true
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.alt_pressed and not mb.shift_pressed:
				return true
			if mb.shift_pressed and not mb.alt_pressed:
				return true
			if mb.ctrl_pressed or mb.meta_pressed:
				return true
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var steps := 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			if mb.shift_pressed:
				steps *= 2.5
			zoom_wheel_steps(steps)
			return true
	elif event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		var zf: float = 1.0 - (mag.factor - 1.0) * 0.5
		zf = clampf(zf, 0.8, 1.2)
		_distance = clampf(_distance * zf, MIN_DISTANCE, MAX_DISTANCE)
		_apply()
		return true
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _mmb_orbit:
			orbit_from_mouse_delta(mm.relative.x, mm.relative.y)
			return true
		if _mmb_pan:
			pan_from_mouse_delta(mm.relative.x, mm.relative.y)
			return true
		var mask := mm.button_mask
		if (mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if Input.is_key_pressed(KEY_ALT) and not Input.is_key_pressed(KEY_SHIFT):
				orbit_from_mouse_delta(mm.relative.x, mm.relative.y)
				return true
			if Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_ALT):
				pan_from_mouse_delta(mm.relative.x, mm.relative.y)
				return true
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
				var zoom_factor: float = 1.0 + mm.relative.y * 0.0012
				zoom_factor = clampf(zoom_factor, 0.85, 1.15)
				_distance = clampf(_distance * zoom_factor, MIN_DISTANCE, MAX_DISTANCE)
				_apply()
				return true
	return false


func handle_key_view(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	match event.keycode:
		KEY_KP_7, KEY_1:
			set_view_preset("top")
			return true
		KEY_KP_1, KEY_2:
			set_view_preset("front")
			return true
		KEY_KP_3, KEY_3:
			set_view_preset("right")
			return true
		KEY_KP_0, KEY_4:
			set_view_preset("persp")
			return true
		KEY_HOME, KEY_R:
			reset_view()
			return true
	return false


func reset_view() -> void:
	global_position = Vector3.ZERO
	_distance = 14.0
	set_view_preset("persp")


func set_view_preset(name: String) -> void:
	match name:
		"top", "front", "right":
			_view_preset = name
		"persp":
			_view_preset = "persp"
			_yaw = deg_to_rad(35.0)
			_pitch = deg_to_rad(30.0)
		_:
			return
	_distance = maxf(_distance, 12.0)
	_apply()


func set_preset_top() -> void:
	set_view_preset("top")


func set_preset_front() -> void:
	set_view_preset("front")


func set_preset_right() -> void:
	set_view_preset("right")


func set_preset_iso() -> void:
	set_view_preset("persp")
	global_position = Vector3.ZERO
	_distance = 14.0
	_apply()


func is_perspective_preset() -> bool:
	return _view_preset == "persp"


func current_view_preset() -> String:
	"""Nombre del preset activo: ``top``/``front``/``right``/``persp``."""
	return _view_preset


func _maybe_emit_viewport_projection_mode() -> void:
	var want: bool = is_perspective_preset()
	if want == _last_perspective_mode_emitted:
		return
	_last_perspective_mode_emitted = want
	viewport_projection_mode_changed.emit(want)


func orbit_from_mouse_delta(dx: float, dy: float) -> void:
	_ensure_perspective_for_orbit()
	_yaw -= dx * ORBIT_SENS
	_pitch -= dy * ORBIT_SENS
	_apply()


func pan_from_mouse_delta(dx: float, dy: float) -> void:
	var right: Vector3 = camera.global_transform.basis.x
	var up: Vector3 = camera.global_transform.basis.y
	var s: float = PAN_SENS * maxf(_distance * 0.06, 0.08)
	global_position -= right * dx * s
	global_position += up * dy * s
	_apply()


func zoom_wheel_steps(steps: float) -> void:
	if steps == 0.0:
		return
	var f := pow(1.1, steps)
	_distance = clampf(_distance * f, MIN_DISTANCE, MAX_DISTANCE)
	_apply()


func _apply() -> void:
	if not is_instance_valid(camera):
		return
	if _view_preset != "persp":
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.fov = PERSP_FOV
		_place_ortho_camera(_view_preset)
		camera.size = clampf(_distance * ORTHO_SIZE_SCALE, 2.0, 280.0)
		camera.near = 0.05
		camera.far = 4000.0
		_maybe_emit_viewport_projection_mode()
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = PERSP_FOV
	camera.size = 1.0
	_pitch = clampf(_pitch, -PITCH_LIMIT, PITCH_LIMIT)
	var cp: float = cos(_pitch)
	var sp: float = sin(_pitch)
	var cy: float = cos(_yaw)
	var sy: float = sin(_yaw)
	var dir := Vector3(cp * cy, cp * sy, sp)
	camera.position = dir * _distance
	camera.look_at(Vector3.ZERO, Vector3(0.0, 0.0, 1.0))
	_maybe_emit_viewport_projection_mode()


func _place_ortho_camera(kind: String) -> void:
	var d: float = _distance
	match kind:
		"top":
			camera.position = Vector3(0.0, 0.0, d)
			camera.look_at(Vector3.ZERO, Vector3(0.0, 1.0, 0.0))
		"front":
			camera.position = Vector3(0.0, -d, 0.0)
			camera.look_at(Vector3.ZERO, Vector3(0.0, 0.0, 1.0))
		"right":
			camera.position = Vector3(d, 0.0, 0.0)
			camera.look_at(Vector3.ZERO, Vector3(0.0, 0.0, 1.0))
		_:
			camera.position = Vector3(0.0, 0.0, d)
			camera.look_at(Vector3.ZERO, Vector3(0.0, 1.0, 0.0))


func _ensure_perspective_for_orbit() -> void:
	if _view_preset == "persp":
		return
	_sync_spherical_from_camera()
	_view_preset = "persp"


func _sync_spherical_from_camera() -> void:
	var fwd: Vector3 = (-camera.global_transform.basis.z).normalized()
	_pitch = asin(clampf(fwd.z, -1.0, 1.0))
	var horiz_sq: float = maxf(1e-10, 1.0 - fwd.z * fwd.z)
	var horiz: float = sqrt(horiz_sq)
	if horiz > 1e-4:
		_yaw = atan2(fwd.y, fwd.x)
	else:
		_yaw = 0.0


func get_viewport_scale_hint_fragment() -> String:
	if not is_instance_valid(camera):
		return ""
	if _view_preset != "persp":
		var vert_span_m: float = camera.size * 2.0
		return "Ortografica alto encuadre ~%.0f m" % vert_span_m
	return "Perspectiva radio órbita ~%.0f m" % _distance


func frame_ortho_aabb(aabb: AABB) -> void:
	"""Centra y ajusta zoom para ver completo el AABB en vista ortográfica actual."""
	if aabb.size == Vector3.ZERO:
		return
	var center: Vector3 = aabb.position + aabb.size * 0.5
	global_position = center
	var span: float = maxf(aabb.size.x, aabb.size.y)
	if _view_preset == "front":
		span = maxf(aabb.size.x, aabb.size.z)
	elif _view_preset == "right":
		span = maxf(aabb.size.y, aabb.size.z)
	span = maxf(span * ORTHO_FRAME_MARGIN, 2.0)
	_distance = maxf(12.0, span / (2.0 * ORTHO_SIZE_SCALE))
	_apply()
