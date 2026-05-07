# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
class_name ViewportManager
extends RefCounted

## Política de render del ``SubViewport`` principal (ahorro cuando OCC 2D cubre el lienzo).
##
## No contiene matemáticas de cámara; solo ``UPDATE_*``, MSAA y ``debug_draw``.

var _subviewport: SubViewport
var _use_occ_2d_views: bool


func setup(subviewport: SubViewport, use_occ_2d_views: bool) -> void:
	_subviewport = subviewport
	_use_occ_2d_views = use_occ_2d_views


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
	var occ_covers: bool = _use_occ_2d_views and not modelado
	if occ_covers:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
