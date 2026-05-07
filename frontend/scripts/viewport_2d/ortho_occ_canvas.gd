# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends Control

## Lienzo 2D para segmentos OCC del backend. El trazo modelo usa **X/Y** en el datum del nivel base;
## la conversión píxel→mundo no depende de la cámara 3D (solo del snapshot y pan/zoom aquí).

const _WORLD_EPS: float = 1e-9

var _lines_px: Array = []
var _bounds_uv: Array = []
var _map_width_px: int = 0
var _map_height_px: int = 0
var _map_margin_px: int = 24
var _line_color: Color = Color(0.82, 0.88, 0.97, 0.95)
var _line_shadow: Color = Color(0.14, 0.20, 0.28, 0.65)
var _bg_color: Color = Color(0.11, 0.115, 0.138, 1.0)
var _pan_px: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _dragging_pan: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

const _MIN_ZOOM: float = 0.25
const _MAX_ZOOM: float = 8.0
const _ZOOM_STEP: float = 1.12


func clear_snapshot() -> void:
	_lines_px.clear()
	_bounds_uv.clear()
	_map_width_px = 0
	_map_height_px = 0
	queue_redraw()


## Metadatos del último ``draw.ortho_snapshot`` (inverso de ``_fit_to_pixels`` en Python).
func set_occ_mapping(bounds_uv: Array, width_px: int, height_px: int, margin_px: int) -> void:
	_bounds_uv = bounds_uv.duplicate()
	_map_width_px = maxi(1, width_px)
	_map_height_px = maxi(1, height_px)
	_map_margin_px = maxi(0, margin_px)
	queue_redraw()


func has_valid_occ_mapping() -> bool:
	return _bounds_uv.size() >= 4 and _map_width_px > 0 and _map_height_px > 0


func set_snapshot(lines_px: Array) -> void:
	_lines_px = lines_px
	queue_redraw()


func reset_view_transform() -> void:
	_pan_px = Vector2.ZERO
	_zoom = 1.0
	queue_redraw()


func zoom_factor() -> float:
	return _zoom


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging_pan = mb.pressed
			_last_mouse_pos = mb.position
			return true
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var before_local: Vector2 = _screen_to_local_untransformed(mb.position)
			var zf: float = _ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / _ZOOM_STEP
			_zoom = clampf(_zoom * zf, _MIN_ZOOM, _MAX_ZOOM)
			var after_local: Vector2 = _screen_to_local_untransformed(mb.position)
			_pan_px += (after_local - before_local) * _zoom
			queue_redraw()
			return true
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _dragging_pan:
			_pan_px += mm.relative
			_last_mouse_pos = mm.position
			queue_redraw()
			return true
	return false


func _screen_to_local_untransformed(screen_pos: Vector2) -> Vector2:
	var c: Vector2 = size * 0.5
	return (screen_pos - c - _pan_px) / _zoom + c


func to_snapshot_space(screen_pos: Vector2) -> Vector2:
	return _screen_to_local_untransformed(screen_pos)


## Convierte posición en el control a coordenadas ``(u,v)`` del plano proyectado (mundo, eje según ``view``).
## Debe alinearse con ``src/axonbim/handlers/draw.py::_fit_to_pixels``.
func to_projected_world_uv(screen_pos: Vector2) -> Vector2:
	var sp: Vector2 = to_snapshot_space(screen_pos)
	if not has_valid_occ_mapping():
		return Vector2(INF, INF)
	var min_u: float = float(_bounds_uv[0])
	var min_v: float = float(_bounds_uv[1])
	var max_u: float = float(_bounds_uv[2])
	var max_v: float = float(_bounds_uv[3])
	var span_u: float = maxf(max_u - min_u, _WORLD_EPS)
	var span_v: float = maxf(max_v - min_v, _WORLD_EPS)
	var w_px: float = float(_map_width_px)
	var h_px: float = float(_map_height_px)
	var margin: float = float(_map_margin_px)
	var inner_w: float = maxf(1.0, w_px - margin * 2.0)
	var inner_h: float = maxf(1.0, h_px - margin * 2.0)
	var scale_px_per_m: float = minf(inner_w / span_u, inner_h / span_v)
	var off_x: float = margin + (inner_w - span_u * scale_px_per_m) * 0.5
	var off_y: float = margin + (inner_h - span_v * scale_px_per_m) * 0.5
	var u: float = min_u + (sp.x - off_x) / scale_px_per_m
	var v: float = min_v + (h_px - sp.y - off_y) / scale_px_per_m
	return Vector2(u, v)


func _apply_transform(p: Vector2) -> Vector2:
	var c: Vector2 = size * 0.5
	return (p - c) * _zoom + c + _pan_px


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color, true)
	_draw_background_grid()
	if _lines_px.is_empty():
		return
	for row in _lines_px:
		if not (row is Array) or row.size() < 4:
			continue
		var x1: float = float(row[0])
		var y1: float = float(row[1])
		var x2: float = float(row[2])
		var y2: float = float(row[3])
		var p1: Vector2 = _apply_transform(Vector2(x1, y1))
		var p2: Vector2 = _apply_transform(Vector2(x2, y2))
		var w: float = maxf(1.2, 1.4 * _zoom)
		draw_line(p1 + Vector2(0.7, 0.7), p2 + Vector2(0.7, 0.7), _line_shadow, w + 0.4, true)
		draw_line(p1, p2, _line_color, w, true)


func _draw_background_grid() -> void:
	var major_step_px: float = 80.0 * _zoom
	var minor_step_px: float = 16.0 * _zoom
	if major_step_px < 12.0:
		return
	var major_col: Color = Color(0.20, 0.26, 0.34, 0.32)
	var minor_col: Color = Color(0.18, 0.23, 0.30, 0.18)
	var origin: Vector2 = _apply_transform(Vector2.ZERO)

	var x: float = fposmod(origin.x, minor_step_px)
	while x <= size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), minor_col, 1.0, true)
		x += minor_step_px
	var y: float = fposmod(origin.y, minor_step_px)
	while y <= size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), minor_col, 1.0, true)
		y += minor_step_px

	var x_major: float = fposmod(origin.x, major_step_px)
	while x_major <= size.x:
		draw_line(Vector2(x_major, 0.0), Vector2(x_major, size.y), major_col, 1.2, true)
		x_major += major_step_px
	var y_major: float = fposmod(origin.y, major_step_px)
	while y_major <= size.y:
		draw_line(Vector2(0.0, y_major), Vector2(size.x, y_major), major_col, 1.2, true)
		y_major += major_step_px
