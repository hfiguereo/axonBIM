# © 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Node3D

## Dibuja datums de ``IfcBuildingStorey`` en el viewport 3D: perímetro de referencia en el plano
## XY a la cota Z del forjado, etiqueta y **grip** esférico seleccionable (física capa 2).
## La verdad IFC muta solo vía RPC ``project.update_storey`` / ``set_active_storey`` desde la UI.

const COLLISION_LAYER_GRIP: int = 2

var _line_root: Node3D
var _grips: Dictionary = {}  # guid -> StaticBody3D
var _selected_guid: String = ""


func _ready() -> void:
	_line_root = Node3D.new()
	_line_root.name = "StoreyDatumLines"
	add_child(_line_root)


func clear_all() -> void:
	_selected_guid = ""
	_grips.clear()
	for c in _line_root.get_children():
		c.queue_free()
	for ch in get_children():
		if ch == _line_root:
			continue
		ch.queue_free()


func set_selected(guid: String) -> void:
	_selected_guid = guid
	_refresh_grip_materials()


func selected_storey_guid() -> String:
	return _selected_guid


func rebuild(storeys: Array, half_xy: Vector2) -> void:
	## Repinta todos los niveles; conserva ``_selected_guid`` si sigue existiendo.
	var keep: String = _selected_guid
	clear_all()
	_selected_guid = keep
	var hx: float = maxf(float(half_xy.x), 5.0)
	var hy: float = maxf(float(half_xy.y), 5.0)
	for row in storeys:
		if not row is Dictionary:
			continue
		var d: Dictionary = row as Dictionary
		var guid: String = str(d.get("guid", ""))
		if guid.is_empty():
			continue
		var nm: String = str(d.get("name", ""))
		var el: float = float(d.get("elevation_m", 0.0))
		var is_active: bool = bool(d.get("is_active", false))
		_add_perimeter_mesh(hx, hy, el, is_active)
		_add_label(nm, el, hx, hy, is_active)
		_add_grip(guid, hx, hy, el, is_active)
	if _selected_guid != "" and not _grips.has(_selected_guid):
		_selected_guid = ""
	_refresh_grip_materials()


func pick_grip_at_screen(camera: Camera3D, screen_pos: Vector2) -> String:
	if camera == null:
		return ""
	var w3d: World3D = get_world_3d()
	if w3d == null:
		return ""
	var space: PhysicsDirectSpaceState3D = w3d.direct_space_state
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var target: Vector3 = origin + camera.project_ray_normal(screen_pos) * 500.0
	var pq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	pq.collide_with_bodies = true
	pq.collision_mask = COLLISION_LAYER_GRIP
	var hit: Dictionary = space.intersect_ray(pq)
	if hit.is_empty():
		return ""
	var col: Variant = hit.get("collider")
	if col is CollisionObject3D and (col as CollisionObject3D).has_meta("axon_storey_guid"):
		return str((col as CollisionObject3D).get_meta("axon_storey_guid"))
	return ""


func _add_perimeter_mesh(hx: float, hy: float, z: float, is_active: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = _make_xy_rectangle_lines_mesh(hx, hy, z + 0.008, is_active)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1, 1, 1, 1)
	mi.material_override = mat
	_line_root.add_child(mi)


func _make_xy_rectangle_lines_mesh(hx: float, hy: float, z: float, is_active: bool) -> ArrayMesh:
	var col: Color = (
		Color(0.35, 0.95, 1.0, 0.95) if is_active else Color(0.28, 0.72, 0.92, 0.55)
	)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var p00 := Vector3(-hx, -hy, z)
	var p10 := Vector3(hx, -hy, z)
	var p11 := Vector3(hx, hy, z)
	var p01 := Vector3(-hx, hy, z)
	for ab: Array in [[p00, p10], [p10, p11], [p11, p01], [p01, p00]]:
		var a: Vector3 = ab[0] as Vector3
		var b: Vector3 = ab[1] as Vector3
		verts.append(a)
		verts.append(b)
		colors.append(col)
		colors.append(col)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return out


func _add_label(nm: String, elevation_z: float, hx: float, hy: float, is_active: bool) -> void:
	var lbl := Label3D.new()
	lbl.text = "%s  (%.2f m)" % [nm, elevation_z]
	lbl.font_size = 19
	lbl.modulate = Color(1.0, 0.92, 0.55, 1.0) if is_active else Color(0.9, 0.94, 1.0, 1.0)
	lbl.position = Vector3(-hx + 0.4, -hy + 0.4, elevation_z + 0.05)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	_line_root.add_child(lbl)


func _add_grip(guid: String, hx: float, hy: float, elevation_z: float, is_active: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = COLLISION_LAYER_GRIP
	body.collision_mask = 0
	body.set_meta("axon_storey_guid", guid)
	body.set_meta("axon_storey_is_active", is_active)
	var col_shape := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.34
	col_shape.shape = sp
	body.add_child(col_shape)
	var gx: float = clampf(hx * 0.72, 2.5, 120.0)
	var gy: float = clampf(hy * 0.72, 2.5, 120.0)
	body.position = Vector3(gx, gy, elevation_z + 0.38)
	var meshi := MeshInstance3D.new()
	meshi.name = "DatumGripMesh"
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	meshi.mesh = sm
	meshi.material_override = _grip_material(is_active, guid == _selected_guid)
	body.add_child(meshi)
	add_child(body)
	_grips[guid] = body


func _grip_material(is_active: bool, is_selected: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if is_selected:
		mat.albedo_color = Color(0.98, 0.45, 0.12, 0.98)
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.35, 0.05)
		mat.emission_energy_multiplier = 0.55
	elif is_active:
		mat.albedo_color = Color(0.95, 0.78, 0.15, 0.95)
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.65, 0.08)
		mat.emission_energy_multiplier = 0.35
	else:
		mat.albedo_color = Color(0.68, 0.74, 0.82, 0.9)
	mat.metallic = 0.12
	mat.roughness = 0.42
	return mat


func _refresh_grip_materials() -> void:
	for g in _grips.keys():
		var body: StaticBody3D = _grips[g] as StaticBody3D
		var meshi: MeshInstance3D = body.get_node_or_null("DatumGripMesh") as MeshInstance3D
		if meshi == null:
			continue
		var is_active: bool = bool(body.get_meta("axon_storey_is_active", false))
		var sel: bool = g == _selected_guid
		meshi.material_override = _grip_material(is_active, sel)
