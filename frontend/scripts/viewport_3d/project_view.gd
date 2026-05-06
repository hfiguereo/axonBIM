# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node3D

## Contenedor del proyecto 3D. Mantiene el mapa `guid -> MeshInstance3D`
## para poder actualizar o eliminar entidades en sprints futuros. Sprint 1.4.
##
## Fase 2: colisión trimesh para ``face_index`` estable; ``pick_face_at_screen`` devuelve
## ``topo_id`` por triángulo. El resaltado de hover agrupa **todos los triángulos** que
## comparten el mismo ``topo_id`` (cara lógica B-Rep), no solo el triángulo bajo el rayo.
## ``replace_entity_mesh`` refresca tras ``geom.extrude_face``.
##
## Los clics en el viewport se manejan en ``main_scene.gd`` vía
## ``SubViewportContainer.gui_input`` (ver ``docs/architecture/app-gui-viewport-patterns.md``).

const MeshBuilder := preload("res://scripts/viewport_3d/mesh_builder.gd")
const ENTITY_NAME_PREFIX: String = "Entity_"
const PICK_RAY_LENGTH_M: float = 500.0
const FACE_HOVER_OFFSET_M: float = 0.002

var _entities: Dictionary = {}  # String guid -> MeshInstance3D
var _triangle_topo: Dictionary = {}  # guid -> Array[String] (una por triángulo)
var _material: StandardMaterial3D = _default_material()
var _highlight: StandardMaterial3D = _highlight_material()
var _edit_highlight: StandardMaterial3D = _edit_highlight_material()
var _hover_preview_mat: StandardMaterial3D = _face_hover_preview_material()
var _hover_locked_mat: StandardMaterial3D = _face_hover_locked_material()
var _selected_guid: String = ""
var _edit_guid: String = ""
var _active_face_topo: Dictionary = {}  # guid -> topo_id de la última cara editada.
var _face_hover_mi: MeshInstance3D
var _face_hover_locked: bool = false


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
	clear_face_hover()
	var mi: MeshInstance3D = _entities[guid]
	_strip_physics_children(mi)
	mi.mesh = MeshBuilder.build_array_mesh(mesh_dict)
	_store_topo_ids(guid, mesh_dict)
	mi.create_trimesh_collision()
	_refresh_entity_overlay(guid)


func remove_entity(guid: String) -> void:
	if not _entities.has(guid):
		return
	if _selected_guid == guid:
		_selected_guid = ""
	if _edit_guid == guid:
		_edit_guid = ""
	_active_face_topo.erase(guid)
	_triangle_topo.erase(guid)
	var node: MeshInstance3D = _entities[guid]
	node.queue_free()
	_entities.erase(guid)


func clear_selection() -> void:
	set_selection("")


func set_selection(guid: String) -> void:
	var previous_guid: String = _selected_guid
	_selected_guid = guid
	_refresh_entity_overlay(previous_guid)
	_refresh_entity_overlay(guid)


func set_edit_target(guid: String) -> void:
	"""Define el elemento editable; vacío sale del modo edición."""
	var previous_guid: String = _edit_guid
	_edit_guid = guid if guid != "" and _entities.has(guid) else ""
	if _edit_guid != "":
		_selected_guid = _edit_guid
	_refresh_entity_overlay(previous_guid)
	_refresh_entity_overlay(_selected_guid)
	clear_face_hover()


func clear_edit_target() -> void:
	set_edit_target("")


func pick_entity_at_screen(camera: Camera3D, screen_pos: Vector2) -> String:
	var hit: Dictionary = _raycast_hit(camera, screen_pos)
	if hit.is_empty():
		set_selection("")
		return ""
	var guid: String = _guid_from_collider(hit.get("collider"))
	set_selection(guid)
	return guid


## ``{ "ok", "guid", "topo_id", "normal", "position", "face_index" }`` o ``{ "ok": false }``.
func pick_face_at_screen(camera: Camera3D, screen_pos: Vector2) -> Dictionary:
	var hit: Dictionary = _raycast_hit(camera, screen_pos)
	if hit.is_empty():
		return {"ok": false}
	var guid: String = _guid_from_collider(hit.get("collider"))
	if guid == "":
		return {"ok": false}
	if _edit_guid != "" and guid != _edit_guid:
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
		"face_index": fi,
	}


## Quita resaltado y desbloquea (fin de herramienta, sustitucion de malla, error RPC).
func clear_face_hover() -> void:
	_face_hover_locked = false
	if _face_hover_mi != null:
		_face_hover_mi.visible = false


func _hide_face_hover_preview_only() -> void:
	if _face_hover_locked:
		return
	if _face_hover_mi != null:
		_face_hover_mi.visible = false


## Resalta la cara bajo el cursor (solo si no hay cara bloqueada por clic previo).
func update_face_hover_at_screen(camera: Camera3D, screen_pos: Vector2) -> void:
	if _face_hover_locked:
		return
	var hit: Dictionary = pick_face_at_screen(camera, screen_pos)
	if not bool(hit.get("ok", false)):
		_hide_face_hover_preview_only()
		return
	_show_face_hover_mesh(hit, _hover_preview_mat)


## Mantiene visible la cara elegida entre el primer y el segundo clic.
func lock_face_hover_from_hit(hit: Dictionary) -> void:
	if not bool(hit.get("ok", false)):
		return
	_face_hover_locked = true
	_show_face_hover_mesh(hit, _hover_locked_mat)


func _ensure_face_hover_node() -> void:
	if _face_hover_mi != null:
		return
	_face_hover_mi = MeshInstance3D.new()
	_face_hover_mi.name = "FaceHoverPreview"
	add_child(_face_hover_mi)


func _show_face_hover_mesh(hit: Dictionary, mat: StandardMaterial3D) -> void:
	var guid: String = str(hit.get("guid", ""))
	var fi: int = int(hit.get("face_index", -1))
	if guid == "" or not _entities.has(guid) or fi < 0:
		if _face_hover_locked:
			clear_face_hover()
		else:
			_hide_face_hover_preview_only()
		return
	var mi: MeshInstance3D = _entities[guid] as MeshInstance3D
	var topo_id: String = str(hit.get("topo_id", ""))
	var tri_mesh: ArrayMesh = null
	if topo_id != "":
		tri_mesh = _logical_face_hover_mesh(mi, guid, topo_id, hit["normal"] as Vector3)
	if tri_mesh == null:
		tri_mesh = _triangle_hover_mesh(mi, fi, hit["normal"] as Vector3)
	if tri_mesh == null:
		if _face_hover_locked:
			clear_face_hover()
		else:
			_hide_face_hover_preview_only()
		return
	_ensure_face_hover_node()
	_face_hover_mi.mesh = tri_mesh
	_face_hover_mi.material_override = mat
	_face_hover_mi.position = Vector3.ZERO
	_face_hover_mi.rotation = Vector3.ZERO
	_face_hover_mi.scale = Vector3.ONE
	_face_hover_mi.visible = true


func _triangle_hover_mesh(
	mi: MeshInstance3D, face_idx: int, hit_normal_world: Vector3
) -> ArrayMesh:
	var src: Mesh = mi.mesh
	if src == null or src.get_surface_count() < 1:
		return null
	var mdt: MeshDataTool = MeshDataTool.new()
	if mdt.create_from_surface(src, 0) != OK:
		return null
	var av: PackedVector3Array = PackedVector3Array()
	var an: PackedVector3Array = PackedVector3Array()
	var ix: PackedInt32Array = PackedInt32Array()
	if not _append_face_triangle_project(mi, mdt, face_idx, hit_normal_world, av, an, ix):
		return null
	return _arraymesh_from_tri_arrays(av, an, ix)


func _logical_face_hover_mesh(
	mi: MeshInstance3D, guid: String, topo_id: String, hit_normal_world: Vector3
) -> ArrayMesh:
	var topos: Array = _triangle_topo.get(guid, []) as Array
	if topos.is_empty():
		return null
	var src: Mesh = mi.mesh
	if src == null or src.get_surface_count() < 1:
		return null
	var mdt: MeshDataTool = MeshDataTool.new()
	if mdt.create_from_surface(src, 0) != OK:
		return null
	var fc: int = mdt.get_face_count()
	var av: PackedVector3Array = PackedVector3Array()
	var an: PackedVector3Array = PackedVector3Array()
	var ix: PackedInt32Array = PackedInt32Array()
	for face_idx in range(fc):
		if face_idx >= topos.size():
			break
		if str(topos[face_idx]) != topo_id:
			continue
		_append_face_triangle_project(mi, mdt, face_idx, hit_normal_world, av, an, ix)
	if ix.is_empty():
		return null
	return _arraymesh_from_tri_arrays(av, an, ix)


func _append_face_triangle_project(
	mi: MeshInstance3D,
	mdt: MeshDataTool,
	face_idx: int,
	hit_normal_world: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
) -> bool:
	var fc: int = mdt.get_face_count()
	if face_idx < 0 or face_idx >= fc:
		return false
	var iv0: int = mdt.get_face_vertex(face_idx, 0)
	var iv1: int = mdt.get_face_vertex(face_idx, 1)
	var iv2: int = mdt.get_face_vertex(face_idx, 2)
	var v0: Vector3 = mdt.get_vertex(iv0)
	var v1: Vector3 = mdt.get_vertex(iv1)
	var v2: Vector3 = mdt.get_vertex(iv2)
	var nloc: Vector3 = (v1 - v0).cross(v2 - v0)
	if nloc.length_squared() < 1e-12:
		return false
	nloc = nloc.normalized()
	var xf: Transform3D = mi.global_transform
	var n_world_geom: Vector3 = (xf.basis * nloc).normalized()
	var hit_n: Vector3 = hit_normal_world.normalized()
	if hit_n.length_squared() > 1e-12 and n_world_geom.dot(hit_n) < 0.0:
		nloc = -nloc
	v0 += nloc * FACE_HOVER_OFFSET_M
	v1 += nloc * FACE_HOVER_OFFSET_M
	v2 += nloc * FACE_HOVER_OFFSET_M
	var g0: Vector3 = xf * v0
	var g1: Vector3 = xf * v1
	var g2: Vector3 = xf * v2
	var gn: Vector3 = xf.basis * nloc
	if gn.length_squared() > 1e-12:
		gn = gn.normalized()
	var inv_pv: Transform3D = global_transform.affine_inverse()
	var l0: Vector3 = inv_pv * g0
	var l1: Vector3 = inv_pv * g1
	var l2: Vector3 = inv_pv * g2
	var ln: Vector3 = inv_pv.basis * gn
	if ln.length_squared() > 1e-12:
		ln = ln.normalized()
	var b: int = vertices.size()
	vertices.push_back(l0)
	vertices.push_back(l1)
	vertices.push_back(l2)
	normals.push_back(ln)
	normals.push_back(ln)
	normals.push_back(ln)
	indices.push_back(b)
	indices.push_back(b + 1)
	indices.push_back(b + 2)
	return true


func _arraymesh_from_tri_arrays(
	vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array
) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var out: ArrayMesh = ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func entity_count() -> int:
	return _entities.size()


func has_entity(guid: String) -> bool:
	return _entities.has(guid)


## Dimensiones de la caja alineada a **ejes mundiales** que envuelve la malla (metros).
func get_entity_mesh_world_aabb_size(guid: String) -> Vector3:
	if not _entities.has(guid):
		return Vector3.ZERO
	var mi: MeshInstance3D = _entities[guid] as MeshInstance3D
	var src: Mesh = mi.mesh
	if src == null or src.get_surface_count() < 1:
		return Vector3.ZERO
	var mdt: MeshDataTool = MeshDataTool.new()
	if mdt.create_from_surface(src, 0) != OK:
		return Vector3.ZERO
	var xf: Transform3D = mi.global_transform
	var vmin: Vector3 = Vector3(INF, INF, INF)
	var vmax: Vector3 = Vector3(-INF, -INF, -INF)
	var vc: int = mdt.get_vertex_count()
	for i in range(vc):
		var wv: Vector3 = xf * mdt.get_vertex(i)
		vmin = vmin.min(wv)
		vmax = vmax.max(wv)
	return vmax - vmin


## AABB mundial de todas las entidades visibles. Si no hay entidades, size=Vector3.ZERO.
func get_scene_world_aabb() -> AABB:
	var has_points: bool = false
	var vmin: Vector3 = Vector3(INF, INF, INF)
	var vmax: Vector3 = Vector3(-INF, -INF, -INF)
	for guid in _entities.keys():
		var mi: MeshInstance3D = _entities[guid] as MeshInstance3D
		if mi == null:
			continue
		var src: Mesh = mi.mesh
		if src == null or src.get_surface_count() < 1:
			continue
		var mdt: MeshDataTool = MeshDataTool.new()
		if mdt.create_from_surface(src, 0) != OK:
			continue
		var xf: Transform3D = mi.global_transform
		var vc: int = mdt.get_vertex_count()
		for i in range(vc):
			var wv: Vector3 = xf * mdt.get_vertex(i)
			vmin = vmin.min(wv)
			vmax = vmax.max(wv)
			has_points = true
	if not has_points:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return AABB(vmin, vmax - vmin)


func selected_guid() -> String:
	return _selected_guid


func edit_target_guid() -> String:
	return _edit_guid


func set_active_face_topo(guid: String, topo_id: String) -> void:
	if guid == "" or topo_id == "" or not has_topo_id(guid, topo_id):
		_active_face_topo.erase(guid)
		return
	_active_face_topo[guid] = topo_id


func active_face_topo(guid: String) -> String:
	return str(_active_face_topo.get(guid, ""))


func remap_active_face_topo(guid: String, old_topo_id: String, topo_map: Dictionary) -> void:
	var current_topo_id: String = active_face_topo(guid)
	if current_topo_id == "":
		current_topo_id = old_topo_id
	if current_topo_id == "" or not topo_map.has(current_topo_id):
		return
	set_active_face_topo(guid, str(topo_map[current_topo_id]))


func has_topo_id(guid: String, topo_id: String) -> bool:
	var topos: Array = _triangle_topo.get(guid, []) as Array
	return topo_id in topos


func _refresh_entity_overlay(guid: String) -> void:
	if guid == "" or not _entities.has(guid):
		return
	var mi: MeshInstance3D = _entities[guid]
	if guid == _edit_guid:
		mi.material_overlay = _edit_highlight
	elif guid == _selected_guid:
		mi.material_overlay = _highlight
	else:
		mi.material_overlay = null


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
	mat.albedo_color = Color(0.58, 0.56, 0.52)
	mat.roughness = 0.86
	mat.metallic = 0.0
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


func _edit_highlight_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.62, 1.0, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.roughness = 0.45
	return mat


func _face_hover_preview_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.75, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.55, 0.95)
	mat.emission_energy_multiplier = 0.4
	mat.roughness = 0.45
	return mat


func _face_hover_locked_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.08, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.05)
	mat.emission_energy_multiplier = 0.55
	mat.roughness = 0.4
	return mat
