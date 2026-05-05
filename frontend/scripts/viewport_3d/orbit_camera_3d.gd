# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Camera3D

## Orbita alrededor de un pivote con boton medio + rueda para zoom.
##
## No usa clic izquierdo: reservado para herramientas (muro, push/pull) en
## ``ProjectView``. Boton medio: rotar; rueda: acercar/alejar.
## Shift + boton medio: pan lateral en el plano de vista.
## Atajos de vista (desde ``main_scene.gd``): 1=Top, 2=Frente, 3=Derecha, 4=Perspectiva.
## Navegacion teclado: WASD desplaza pivote en XY, Q/E sube-baja, R reinicia vista.
##
## Modo laptop/trackpad (sin boton medio):
## - Alt + arrastre izquierdo: orbitar
## - Shift + arrastre izquierdo: pan
## - Ctrl/Cmd + arrastre vertical: zoom

@export var pivot: Vector3 = Vector3.ZERO
@export var yaw_sensitivity: float = 0.005
@export var pitch_sensitivity: float = 0.005
@export var zoom_sensitivity: float = 0.12
@export var min_distance: float = 2.0
@export var max_distance: float = 80.0
@export var pan_sensitivity: float = 1.0
@export var keyboard_move_speed: float = 10.0
@export var keyboard_vertical_speed: float = 8.0

var _yaw: float = 0.0
var _pitch: float = 0.45
var _distance: float = 14.0


func _ready() -> void:
	var offset: Vector3 = global_position - pivot
	_distance = clampf(offset.length(), min_distance, max_distance)
	if _distance < 1e-4:
		_distance = 14.0
	# Convencion Z-up (AxonBIM modela sobre XY con extrusión en Z).
	_yaw = atan2(offset.y, offset.x)
	var horiz: float = sqrt(offset.x * offset.x + offset.y * offset.y)
	if horiz < 1e-6:
		_pitch = 0.45
	else:
		_pitch = clampf(atan2(offset.z, horiz), deg_to_rad(-85.0), deg_to_rad(85.0))
	_apply_orbit()
	set_process(true)


func _process(delta: float) -> void:
	var right: Vector3 = global_transform.basis.x
	var fwd_raw: Vector3 = -global_transform.basis.z
	var forward_xy: Vector3 = Vector3(fwd_raw.x, fwd_raw.y, 0.0)
	if forward_xy.length_squared() < 1e-10:
		forward_xy = Vector3(1.0, 0.0, 0.0)
	else:
		forward_xy = forward_xy.normalized()
	var right_xy: Vector3 = Vector3(right.x, right.y, 0.0)
	if right_xy.length_squared() < 1e-10:
		right_xy = Vector3(0.0, 1.0, 0.0)
	else:
		right_xy = right_xy.normalized()

	var move: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move += forward_xy
	if Input.is_key_pressed(KEY_S):
		move -= forward_xy
	if Input.is_key_pressed(KEY_D):
		move += right_xy
	if Input.is_key_pressed(KEY_A):
		move -= right_xy
	if move.length_squared() > 1e-10:
		pivot += move.normalized() * keyboard_move_speed * delta * max(_distance * 0.2, 1.0)
		_apply_orbit()

	var dz: float = 0.0
	if Input.is_key_pressed(KEY_E):
		dz += 1.0
	if Input.is_key_pressed(KEY_Q):
		dz -= 1.0
	if abs(dz) > 0.0:
		pivot.z += dz * keyboard_vertical_speed * delta * max(_distance * 0.15, 1.0)
		_apply_orbit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		var mmb_drag: bool = (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0
		var lmb_drag: bool = (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if mmb_drag:
			if Input.is_key_pressed(KEY_SHIFT):
				_pan_by_mouse_delta(motion.relative)
			else:
				_yaw -= motion.relative.x * yaw_sensitivity
				_pitch -= motion.relative.y * pitch_sensitivity
				_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
				_apply_orbit()
			get_viewport().set_input_as_handled()
		elif lmb_drag:
			if Input.is_key_pressed(KEY_ALT):
				# Trackpad/laptop: Alt + drag izquierdo = órbita.
				_yaw -= motion.relative.x * yaw_sensitivity
				_pitch -= motion.relative.y * pitch_sensitivity
				_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
				_apply_orbit()
				get_viewport().set_input_as_handled()
			elif Input.is_key_pressed(KEY_SHIFT):
				# Trackpad/laptop: Shift + drag izquierdo = pan.
				_pan_by_mouse_delta(motion.relative)
				get_viewport().set_input_as_handled()
			elif Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
				# Trackpad/laptop: Ctrl/Cmd + drag vertical = zoom.
				var zoom_factor: float = 1.0 + motion.relative.y * 0.01 * zoom_sensitivity
				zoom_factor = clampf(zoom_factor, 0.85, 1.15)
				_distance = clampf(_distance * zoom_factor, min_distance, max_distance)
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
	elif event is InputEventMagnifyGesture:
		var mag: InputEventMagnifyGesture = event
		var zoom_factor2: float = 1.0 - (mag.factor - 1.0) * 0.5
		zoom_factor2 = clampf(zoom_factor2, 0.8, 1.2)
		_distance = clampf(_distance * zoom_factor2, min_distance, max_distance)
		_apply_orbit()
		get_viewport().set_input_as_handled()


func set_view_preset(name: String) -> void:
	match name:
		"top":
			# Cámara sobre +Z mirando al plano XY.
			_pitch = deg_to_rad(80.0)
			_yaw = 0.0
		"front":
			# Vista frontal sobre -Y.
			_pitch = 0.0
			_yaw = deg_to_rad(-90.0)
		"right":
			# Vista lateral derecha sobre +X.
			_pitch = 0.0
			_yaw = 0.0
		"persp":
			_pitch = deg_to_rad(30.0)
			_yaw = deg_to_rad(35.0)
	_apply_orbit()


func reset_view() -> void:
	pivot = Vector3.ZERO
	_distance = 14.0
	set_view_preset("persp")


func _pan_by_mouse_delta(delta_px: Vector2) -> void:
	# Escala con distancia para que el pan sea consistente al zoom.
	var speed: float = pan_sensitivity * (_distance * 0.0025)
	var right: Vector3 = global_transform.basis.x
	var up_screen: Vector3 = global_transform.basis.y
	pivot += (-right * delta_px.x + up_screen * delta_px.y) * speed
	_apply_orbit()


func _apply_orbit() -> void:
	var cp: float = cos(_pitch)
	var dir: Vector3 = Vector3(cp * cos(_yaw), cp * sin(_yaw), sin(_pitch))
	global_position = pivot + dir * _distance
	look_at(pivot, Vector3(0, 0, 1))
