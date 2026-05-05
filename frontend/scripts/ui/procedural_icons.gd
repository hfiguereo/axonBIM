# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends RefCounted
class_name ProceduralIcons

const ICON_SIZE: int = 36
const COLOR_FG := Color(0.16, 0.18, 0.22, 1.0)
const COLOR_ACCENT := Color(0.17, 0.53, 0.90, 1.0)
const COLOR_ACCENT_SOFT := Color(0.17, 0.53, 0.90, 0.35)


static func build_wall_icon(size: int = ICON_SIZE) -> Texture2D:
	var img: Image = _new_canvas(size)
	var l: int = size / 6
	var t: int = size / 4
	var r: int = size - l
	var b: int = size - size / 5
	_draw_rect_outline(img, l, t, r, b, COLOR_FG, 2)
	var rows: Array[int] = [t + 6, t + 11, t + 16]
	for y: int in rows:
		_draw_line(img, Vector2i(l + 2, y), Vector2i(r - 2, y), COLOR_ACCENT_SOFT, 1)
	_draw_line(img, Vector2i((l + r) / 2, t + 2), Vector2i((l + r) / 2, b - 2), COLOR_ACCENT_SOFT, 1)
	_draw_rect_outline(img, l - 1, t - 1, r + 1, b + 1, COLOR_ACCENT_SOFT, 1)
	return _to_texture(img)


static func build_push_pull_icon(size: int = ICON_SIZE) -> Texture2D:
	var img: Image = _new_canvas(size)
	var cx: int = size / 2
	var top: int = size / 6
	var bottom: int = size - size / 6
	_draw_line(img, Vector2i(cx, top + 3), Vector2i(cx, bottom - 3), COLOR_FG, 2)
	_draw_line(img, Vector2i(cx, top + 1), Vector2i(cx - 5, top + 7), COLOR_ACCENT, 2)
	_draw_line(img, Vector2i(cx, top + 1), Vector2i(cx + 5, top + 7), COLOR_ACCENT, 2)
	_draw_line(img, Vector2i(cx, bottom - 1), Vector2i(cx - 5, bottom - 7), COLOR_ACCENT, 2)
	_draw_line(img, Vector2i(cx, bottom - 1), Vector2i(cx + 5, bottom - 7), COLOR_ACCENT, 2)
	_draw_rect_outline(img, cx - 9, size / 2 - 5, cx + 9, size / 2 + 5, COLOR_FG, 1)
	return _to_texture(img)


static func build_save_icon(size: int = ICON_SIZE) -> Texture2D:
	var img: Image = _new_canvas(size)
	var l: int = size / 5
	var t: int = size / 5
	var r: int = size - l
	var b: int = size - size / 6
	_draw_rect_outline(img, l, t, r, b, COLOR_FG, 2)
	_fill_rect(img, l + 3, t + 3, r - 3, t + 10, COLOR_ACCENT_SOFT)
	_draw_rect_outline(img, l + 4, t + 4, r - 4, t + 9, COLOR_ACCENT, 1)
	_draw_rect_outline(img, l + 6, t + 13, r - 6, b - 5, COLOR_FG, 1)
	_fill_rect(img, l + 9, t + 16, r - 9, b - 8, COLOR_ACCENT_SOFT)
	return _to_texture(img)


static func _new_canvas(size: int) -> Image:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _fill_rect(img: Image, left: int, top: int, right: int, bottom: int, color: Color) -> void:
	for y: int in range(max(top, 0), min(bottom, img.get_height())):
		for x: int in range(max(left, 0), min(right, img.get_width())):
			img.set_pixel(x, y, color)


static func _draw_rect_outline(
	img: Image, left: int, top: int, right: int, bottom: int, color: Color, thickness: int = 1
) -> void:
	for i: int in range(thickness):
		_draw_line(img, Vector2i(left + i, top + i), Vector2i(right - i, top + i), color, 1)
		_draw_line(img, Vector2i(left + i, bottom - i), Vector2i(right - i, bottom - i), color, 1)
		_draw_line(img, Vector2i(left + i, top + i), Vector2i(left + i, bottom - i), color, 1)
		_draw_line(img, Vector2i(right - i, top + i), Vector2i(right - i, bottom - i), color, 1)


static func _draw_line(
	img: Image, from: Vector2i, to: Vector2i, color: Color, thickness: int = 1
) -> void:
	var x0: int = from.x
	var y0: int = from.y
	var x1: int = to.x
	var y1: int = to.y
	var dx: int = absi(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -absi(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		_stamp(img, x0, y0, color, thickness)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _stamp(img: Image, x: int, y: int, color: Color, thickness: int) -> void:
	var rad: int = max(0, thickness - 1)
	for oy: int in range(-rad, rad + 1):
		for ox: int in range(-rad, rad + 1):
			var px: int = x + ox
			var py: int = y + oy
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			img.set_pixel(px, py, color)


static func _to_texture(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img)
