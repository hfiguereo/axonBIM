# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node3D

## Contenedor del proyecto 3D. Mantiene el mapa `guid -> MeshInstance3D`
## para poder actualizar o eliminar entidades en sprints futuros. Sprint 1.4.

const MeshBuilder := preload("res://scripts/viewport_3d/mesh_builder.gd")

var _entities: Dictionary = {}  # String guid -> MeshInstance3D
var _material: StandardMaterial3D = _default_material()


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


func _default_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.78, 0.70)
	mat.roughness = 0.75
	return mat
