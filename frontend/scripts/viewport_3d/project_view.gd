# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node3D

## Contenedor del proyecto 3D. Mantiene el mapa `guid -> MeshInstance3D`
## para poder actualizar o eliminar entidades en sprints futuros. Sprint 1.4.
##
## Fase 2: colisión trimesh para ``face_index`` estable; ``pick_face_at_screen`` devuelve
## ``topo_id`` por triángulo. ``replace_entity_mesh`` refresca tras ``geom.extrude_face``.
##
## Los clics en el viewport se manejan en ``main_scene.gd`` vía
## ``SubViewportContainer.gui_input`` (ver ``docs/architecture/app-gui-viewport-patterns.md``).

const MeshBuilder := preload("res://scripts/viewport_3d/mesh_builder.gd")
const ENTITY_NAME_PREFIX: String = "Entity_"
const PICK_RAY_LENGTH_M: float = 500.0

var _entities: Dictionary = {}  # String guid -> MeshInstance3D
var _triangle_topo: Dictionary = {}  # guid -> Array[String] (una por triángulo)
var _material: StandardMaterial3D = _default_material()
var _highlight: StandardMaterial3D = _highlight_material()
var _selected_guid: String = ""


func add_entity(guid: String, mesh_dict: Dictionary) -> void:
	if _entities.has(guid):
		Logger.warn("Entidad %s ya existe, se sobrescribe" % guid)
		remove_entity(guid)

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = MeshBuilder.build_array_mesh(mesh_dict)
	instance.material_override = _material
	instance.name = "%s%s" % [ENTITY_NAME_PREFIX, guid]
	add_child(instance)
	_store_topo_ids(guid, mesh_dict)
	instance.create_trimesh_collision()
	_entities[guid] = instance


func replace_entity_mesh(guid: String, mesh_dict: Dictionary) -> void:
	if not _entities.has(guid):
		Logger.warn("replace_entity_mesh: no existe %s" % guid)
		return
	var mi: MeshInstance3D = _entities[guid]
	_strip_physics_children(mi)
	mi.mesh = MeshBuilder.build_array_mesh(mesh_dict)
	_store_topo_ids(guid, mesh_dict)
	mi.create_trimesh_collision()


func remove_entity(guid: String) -> void:
	if not _entities.has(guid):
		return
	if _selected_guid == guid:
		_selected_guid = ""
	_triangle_topo.erase(guid)
	var node: MeshInstance3D = _entities[guid]
	node.queue_free()
	_entities.erase(guid)


func clear_selection() -> void:
	set_selection("")


func set_selection(guid: String) -> void:
	if _selected_guid != "" and _entities.has(_selected_guid):
		var prev: MeshInstance3D = _entities[_selected_guid]
		prev.material_overlay = null
	_selected_guid = guid
	if guid != "" and _entities.has(guid):
		var mi: MeshInstance3D = _entities[guid]
		mi.material_overlay = _highlight


func pick_entity_at_screen(camera: Camera3D, screen_pos: Vector2) -> String:
	var hit: Dictionary = _raycast_hit(camera, screen_pos)
	if hit.is_empty():
		set_selection("")
		return ""
	var guid: String = _guid_from_collider(hit.get("collider"))
	set_selection(guid)
	return guid


## ``{ "ok": true, "guid", "topo_id", "normal", "position" }`` o ``{ "ok": false }``.
func pick_face_at_screen(camera: Camera3D, screen_pos: Vector2) -> Dictionary:
	var hit: Dictionary = _raycast_hit(camera, screen_pos)
	if hit.is_empty():
		return {"ok": false}
	var guid: String = _guid_from_collider(hit.get("collider"))
	if guid == "":
		return {"ok": false}
	var fi: int = int(hit.get("face_index", -1))
	if fi < 0:
		return {"ok": false}
	var topos: Array = _triangle_topo.get(guid, []) as Array
	if fi >= topos.size():
		return {"ok": false}
	var topo_id: String = str(topos[fi])
	var n: Variant = hit.get("normal", Vector3.ZERO)
	var p: Variant = hit.get("position", Vector3.ZERO)
	return {
		"ok": true,
		"guid": guid,
		"topo_id": topo_id,
		"normal": n as Vector3,
		"position": p as Vector3,
	}


func entity_count() -> int:
	return _entities.size()


func has_entity(guid: String) -> bool:
	return _entities.has(guid)


func selected_guid() -> String:
	return _selected_guid


func _store_topo_ids(guid: String, mesh_dict: Dictionary) -> void:
	var raw: Variant = mesh_dict.get("topo_ids", [])
	var arr: Array = []
	if raw is Array:
		for x in raw:
			arr.append(str(x))
	_triangle_topo[guid] = arr


func _strip_physics_children(mi: MeshInstance3D) -> void:
	for c in mi.get_children():
		c.queue_free()


func _raycast_hit(camera: Camera3D, screen_pos: Vector2) -> Dictionary:
	if camera == null:
		return {}
	var w3d: World3D = get_world_3d()
	if w3d == null:
		return {}
	var space: PhysicsDirectSpaceState3D = w3d.direct_space_state
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var target: Vector3 = origin + camera.project_ray_normal(screen_pos) * PICK_RAY_LENGTH_M
	var pq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	pq.collide_with_bodies = true
	return space.intersect_ray(pq)


func _guid_from_collider(collider: Variant) -> String:
	if collider == null:
		return ""
	var mi: MeshInstance3D = null
	if collider is MeshInstance3D:
		mi = collider
	elif collider is CollisionObject3D:
		var parent_node: Node = collider.get_parent()
		if parent_node is MeshInstance3D:
			mi = parent_node
	if mi == null:
		return ""
	var n: String = String(mi.name)
	if not n.begins_with(ENTITY_NAME_PREFIX):
		return ""
	return n.substr(ENTITY_NAME_PREFIX.length())


func _default_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.78, 0.70)
	mat.roughness = 0.75
	return mat


func _highlight_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.15, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.05)
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.5
	return mat
