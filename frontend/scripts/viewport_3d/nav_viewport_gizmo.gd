# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends PanelContainer

## Botones de vista rapida (esquina del viewport), enlazados al rig orbital.
##
## Convención: **+Y = norte del proyecto** (planta en XY, Z arriba). N/S/E/O son elevaciones.

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
		"Ortogonal cenital (+Z); fondo plano técnico. Tecla 1 o Num 7",
		func() -> void: _rig.call("set_view_preset", "top")
	)
	_add_btn(
		vb,
		"Norte",
		"Elevación mirando hacia +Y (cámara en -Y). Num 1 / tecla 2",
		func() -> void: _rig.call("set_view_preset", "north")
	)
	_add_btn(
		vb,
		"Sur",
		"Elevación mirando hacia -Y (cámara en +Y). Num 9",
		func() -> void: _rig.call("set_view_preset", "south")
	)
	_add_btn(
		vb,
		"Este",
		"Elevación mirando hacia +X (cámara en -X). Num 4",
		func() -> void: _rig.call("set_view_preset", "east")
	)
	_add_btn(
		vb,
		"Oeste",
		"Elevación mirando hacia -X (cámara en +X). Num 3 / tecla 3",
		func() -> void: _rig.call("set_view_preset", "west")
	)
	_add_btn(
		vb,
		"Persp",
		"Perspectiva (fondo plano). Tecla 4 o Num 0",
		func() -> void: _rig.call("set_view_preset", "persp")
	)
	_add_btn(vb, "Inicio", "Pivote en origen y perspectiva. Inicio o R", func() -> void: _rig.call("reset_view"))


func _add_btn(parent: VBoxContainer, text: String, tip: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(fn)
	parent.add_child(b)
