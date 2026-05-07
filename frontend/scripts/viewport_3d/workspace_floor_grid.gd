# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends MeshInstance3D

## Plano de referencia en **XY** (Z arriba). Atenúa la opacidad en vistas muy
## oblicuas para que no se lea como un plano vertical que cruza la escena;
## en planta (cámara sobre +Z mirando al suelo) se ve con más peso visual.

@export var camera_path: NodePath = NodePath("../CameraRig/Camera3D")
@export var min_alpha_oblique: float = 0.07
@export var max_alpha_plan: float = 0.48

var _camera: Camera3D
var _base_rgb: Vector3 = Vector3(0.42, 0.48, 0.54)
var _last_planarness_bucket: float = -99.0


func _ready() -> void:
	var n := get_node_or_null(camera_path)
	if n is Camera3D:
		_camera = n as Camera3D
	var mat := material_override
	if mat is StandardMaterial3D:
		var c: Color = (mat as StandardMaterial3D).albedo_color
		_base_rgb = Vector3(c.r, c.g, c.b)


func _process(_delta: float) -> void:
	if _camera == null:
		return
	var mat := material_override
	if mat == null or not (mat is StandardMaterial3D):
		return
	var fwd := (-_camera.global_transform.basis.z).normalized()
	# fwd.z negativo ≈ mirar hacia el suelo desde encima del plano XY.
	var planarness: float = clampf((-fwd.z - 0.28) / 0.62, 0.0, 1.0)
	var bucketed: float = snappedf(planarness, 0.02)
	if absf(bucketed - _last_planarness_bucket) < 1e-5:
		return
	_last_planarness_bucket = bucketed
	var a: float = lerpf(min_alpha_oblique, max_alpha_plan, bucketed)
	var smat: StandardMaterial3D = mat as StandardMaterial3D
	smat.albedo_color = Color(_base_rgb.x, _base_rgb.y, _base_rgb.z, a)
