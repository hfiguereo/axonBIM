# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
class_name ViewportManager
extends RefCounted

## Política de render del ``SubViewport`` principal (ahorro cuando una vista 2D vectorial cubre el lienzo).
##
## No contiene matemáticas de cámara; solo ``UPDATE_*``, MSAA y ``debug_draw``.

var _subviewport: SubViewport
var _pause_3d_when_vector2d_tab: bool


func setup(subviewport: SubViewport, pause_3d_when_vector2d_tab: bool) -> void:
	_subviewport = subviewport
	_pause_3d_when_vector2d_tab = pause_3d_when_vector2d_tab


func apply_msaa(msaa: int) -> void:
	if _subviewport != null:
		_subviewport.msaa_3d = msaa


func set_debug_draw(mode: int) -> void:
	if _subviewport != null:
		_subviewport.debug_draw = mode


func update_main_canvas_render_policy(active_view_tab: int, main_canvas_occluded_by_float: bool) -> void:
	if _subviewport == null:
		return
	if main_canvas_occluded_by_float:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var modelado: bool = active_view_tab == 0
	var vector2d_covers: bool = _pause_3d_when_vector2d_tab and not modelado
	if vector2d_covers:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
