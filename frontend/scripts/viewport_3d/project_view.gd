# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
class_name AxonProjectView
extends Node3D

## Contenedor del proyecto 3D. Mantiene el mapa `guid -> MeshInstance3D`
## para poder actualizar o eliminar entidades en sprints futuros. Sprint 1.4.
##
## Clics en el viewport 3D: con ``SubViewport.handle_input_locally = false``,
## los eventos de raton viven dentro del ``SubViewport`` y **no** llegan al
## ``gui_input`` del ``SubViewportContainer``. Por eso reenviamos aqui los
## clics izquierdos como señal en coordenadas del viewport (las que espera
## ``Camera3D.project_ray_origin``).

signal viewport_left_click(viewport_position: Vector2)

const MeshBuilder := preload("res://scripts/viewport_3d/mesh_builder.gd")

var _entities: Dictionary = {}  # String guid -> MeshInstance3D
var _material: StandardMaterial3D = _default_material()
var _forward_wall_clicks: bool = false


func add_entity(guid: String, mesh_dict: Dictionary) -> void:
	if _entities.has(guid):
		Logger.warn("Entidad %s ya existe, se sobrescribe" % guid)
		remove_entity(guid)

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = MeshBuilder.build_array_mesh(mesh_dict)
	instance.material_override = _material
	instance.name = "Entity_%s" % guid
	add_child(instance)
	_entities[guid] = instance


func remove_entity(guid: String) -> void:
	if not _entities.has(guid):
		return
	var node: MeshInstance3D = _entities[guid]
	node.queue_free()
	_entities.erase(guid)


func entity_count() -> int:
	return _entities.size()


func has_entity(guid: String) -> bool:
	return _entities.has(guid)


## Activa/desactiva la captura de clics para la herramienta "crear muro".
func set_wall_clicks_enabled(enabled: bool) -> void:
	_forward_wall_clicks = enabled


func _unhandled_input(event: InputEvent) -> void:
	if not _forward_wall_clicks:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			viewport_left_click.emit(mouse.position)
			get_viewport().set_input_as_handled()


func _default_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.78, 0.70)
	mat.roughness = 0.75
	return mat
