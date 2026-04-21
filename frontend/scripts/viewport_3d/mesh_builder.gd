# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends RefCounted

## Convierte el payload RPC `{vertices, indices, normals}` en un `ArrayMesh`
## listo para asignar a un `MeshInstance3D`. Sprint 1.4.


static func build_array_mesh(mesh_dict: Dictionary) -> ArrayMesh:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)

	var vertices: PackedVector3Array = _to_vector3_array(mesh_dict.get("vertices", []))
	var normals: PackedVector3Array = _to_vector3_array(mesh_dict.get("normals", []))
	var indices: PackedInt32Array = _to_int_array(mesh_dict.get("indices", []))

	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = indices

	var out: ArrayMesh = ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


static func _to_vector3_array(flat: Array) -> PackedVector3Array:
	var arr: PackedVector3Array = PackedVector3Array()
	var n: int = flat.size() / 3
	arr.resize(n)
	for i in range(n):
		arr[i] = Vector3(flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2])
	return arr


static func _to_int_array(flat: Array) -> PackedInt32Array:
	var arr: PackedInt32Array = PackedInt32Array()
	arr.resize(flat.size())
	for i in range(flat.size()):
		arr[i] = int(flat[i])
	return arr
