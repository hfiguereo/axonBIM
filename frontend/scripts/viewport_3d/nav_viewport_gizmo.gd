# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends PanelContainer

## Botones de vista rapida (esquina del viewport), enlazados al rig orbital.

@export var rig_path: NodePath = NodePath("../../SubViewport/World/CameraRig")

var _rig: Node


func _ready() -> void:
	var n := get_node_or_null(rig_path)
	if n != null and n.has_method("set_view_preset"):
		_rig = n
	else:
		push_warning("NavViewportGizmo: rig invalido en %s" % str(rig_path))
		return
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	_add_btn(
		vb,
		"Planta",
		"Ortogonal cenital (+Z); fondo plano técnico (sin horizonte de cielo). Tecla 1 o Num 7",
		func() -> void: _rig.call("set_view_preset", "top")
	)
	_add_btn(
		vb,
		"Frente",
		"Ortogonal hacia el plano Y; fondo plano. Tecla 2 o Num 1",
		func() -> void: _rig.call("set_view_preset", "front")
	)
	_add_btn(
		vb,
		"Derecha",
		"Ortogonal hacia el plano X; fondo plano. Tecla 3 o Num 3",
		func() -> void: _rig.call("set_view_preset", "right")
	)
	_add_btn(
		vb,
		"Persp",
		"Perspectiva (fondo plano; orbita desde orto mantiene encuadre). Tecla 4 o Num 0",
		func() -> void: _rig.call("set_view_preset", "persp")
	)
	_add_btn(vb, "Inicio", "Pivote en origen y perspectiva. Inicio o R", func() -> void: _rig.call("reset_view"))


func _add_btn(parent: VBoxContainer, text: String, tip: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(fn)
	parent.add_child(b)
