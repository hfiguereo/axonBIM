# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
extends RefCounted
class_name ProceduralIcons

const ICON_SIZE: int = 36
const COLOR_BG := Color(0.12, 0.12, 0.14, 1.0)
const COLOR_FG := Color(0.92, 0.92, 0.95, 1.0)
const COLOR_ACCENT := Color(0.24, 0.68, 1.0, 1.0)


static func build_wall_icon(size: int = ICON_SIZE) -> Texture2D:
	var img: Image = _new_canvas(size)
	_fill_rect(img, 8, 10, size - 8, size - 9, COLOR_FG)
	_fill_rect(img, 10, 12, size - 10, size - 11, COLOR_BG)
	_fill_rect(img, 8, 17, size - 8, 19, COLOR_ACCENT)
	return _to_texture(img)


static func build_push_pull_icon(size: int = ICON_SIZE) -> Texture2D:
	var img: Image = _new_canvas(size)
	var mid_x: int = size / 2
	_fill_rect(img, mid_x - 2, 8, mid_x + 2, size - 8, COLOR_FG)
	_fill_rect(img, mid_x - 8, 8, mid_x + 8, 10, COLOR_FG)
	_fill_rect(img, mid_x - 8, size - 10, mid_x + 8, size - 8, COLOR_FG)
	_fill_rect(img, mid_x - 10, 11, mid_x + 10, 13, COLOR_ACCENT)
	_fill_rect(img, mid_x - 10, size - 13, mid_x + 10, size - 11, COLOR_ACCENT)
	return _to_texture(img)


static func build_save_icon(size: int = ICON_SIZE) -> Texture2D:
	var img: Image = _new_canvas(size)
	_fill_rect(img, 8, 8, size - 8, size - 8, COLOR_FG)
	_fill_rect(img, 12, 12, size - 12, 18, COLOR_BG)
	_fill_rect(img, 12, 22, size - 12, size - 12, COLOR_BG)
	_fill_rect(img, 18, 24, size - 18, size - 15, COLOR_ACCENT)
	return _to_texture(img)


static func _new_canvas(size: int) -> Image:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _fill_rect(img: Image, left: int, top: int, right: int, bottom: int, color: Color) -> void:
	for y: int in range(max(top, 0), min(bottom, img.get_height())):
		for x: int in range(max(left, 0), min(right, img.get_width())):
			img.set_pixel(x, y, color)


static func _to_texture(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img)
