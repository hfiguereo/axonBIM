# Topological Naming — AxonBIM

## El problema

En modelado paramétrico B-Rep (Boundary Representation), cada operación geométrica puede regenerar la topología: caras se dividen, aristas se fusionan, vértices aparecen y desaparecen. Si el usuario "estiró la cara superior" del muro y luego ejecutamos una booleana, **¿cuál es ahora la cara superior?**

Los kernels CAD típicos asignan IDs internos efímeros que cambian entre operaciones. Si Godot guardara esos IDs, el siguiente "Push/Pull" sobre la misma cara fallaría: la cara ya no existe con ese ID.

Este es el **Topological Naming Problem** — el talón de Aquiles de FreeCAD durante años, y la razón por la que muchos modelos paramétricos se "rompen" al editar.

## Estrategia de AxonBIM

Cada cara, arista y vértice B-Rep recibe un **`topo_id` persistente** generado por el backend. El frontend nunca conoce la indexación interna del kernel geométrico; solo maneja `topo_id`s opacos.

### Algoritmo de generación

```
topo_id = sha1(
    entity_type ||                    # "FACE" | "EDGE" | "VERTEX"
    canonical_geometry_signature ||   # ver abajo
    parent_guid ||                    # GUID IFC del elemento padre (muro, losa…)
    creation_op_signature             # operación que originó la entidad
)[:16]                                 # primeros 16 hex = 64 bits, suficiente
```

### Firma geométrica canónica

Para que el hash sea **estable bajo round-trip** (guardar IFC → reabrir → mismo ID):

| Tipo | Firma |
|------|-------|
| **Vértice** | `(round(x, 6), round(y, 6), round(z, 6))` en metros |
| **Arista** | `tipo_curva + endpoints_ordenados + parámetros` (ordenados lexicográficamente) |
| **Cara** | `tipo_superficie + bbox_redondeado + normal_canónica + cantidad_de_loops + hash_de_loops_externos` |

Tolerancia de redondeo: `1e-6 m` (1 micrón). Suficiente para BIM arquitectónico, evita falsos positivos por ruido numérico.

### Mapa de transición

Toda operación que muta topología devuelve un **`topo_map`** en su respuesta RPC:

```json
{
  "topo_map": {
    "a1b2c3d4...": "f5e6d7c8...",   // la cara vieja se convirtió en esta nueva
    "11223344...": ["aabbccdd...", "eeff0011..."]  // la cara vieja se dividió en dos
  }
}
```

Godot actualiza su tabla local `viewport_node → topo_id` en una sola pasada tras recibir cada response.

### Casos especiales

| Situación | Comportamiento |
|-----------|----------------|
| Cara desaparece (consumida por booleana) | Aparece como key en `topo_map` con value `null` |
| Cara se divide en N | Value es una lista de `topo_id`s |
| N caras se fusionan en 1 | Múltiples keys mapean al mismo value |
| Operación crea geometría completamente nueva | No aparece en `topo_map`; el cliente la trata como entidad recién nacida |

## Persistencia

Los `topo_id` se serializan como **propiedades IFC custom** (`Pset_AxonBIM_Topology`) sobre cada `IfcRepresentationItem`. Al reabrir un IFC generado por AxonBIM, los IDs se restauran tal cual.

Para IFC importados desde otros softwares (sin nuestra `Pset`), generamos los IDs al vuelo en la primera lectura y los persistimos al primer guardado.

## Para implementadores

- El módulo canónico es `src/axonbim/geometry/topology.py`.
- Función pública: `compute_topo_id(entity, parent_guid, op_signature) -> str`.
- Función pública: `propagate_topology(old_shape, new_shape) -> dict[str, str | list[str] | None]`.
- Tests obligatorios para round-trip: crear → guardar IFC → reabrir → verificar IDs idénticos.

## Referencias

- Hoffmann & Joan-Arinyo (1998). *Symbolic Constraints in Constructive Geometric Constraint Solving*.
- FreeCAD wiki: [Topological Naming Problem](https://wiki.freecadweb.org/Topological_naming_problem).
- Onshape blog: *How Onshape solves topological naming*.
