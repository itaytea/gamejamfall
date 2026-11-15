class_name HeadIcon
extends RefCounted
## Tiny head icons for resident lists, made from the same modular parts as the
## door portrait (body + face + hair), cropped to the head and shrunk. Cached per look.

const PARTS_DIR := "res://Sprites/npc modes/"
const HEAD_RECT := Rect2i(10, 0, 72, 66)     # Head area on the 90x110 portrait canvas
const ICON_SIZE := Vector2i(12, 11)

static var _cache := {}


static func for_resident(r: Resident) -> Texture2D:
	var key := "%d-%d-%d" % [r.base_id, r.face_id, r.hair_id]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(90, 110, false, Image.FORMAT_RGBA8)
	for part in [["BASE", "npc_base", r.base_id], ["FACE", "npc_face", r.face_id], ["HAIR", "npc_hair", r.hair_id]]:
		var tex: Texture2D = load("%s%s/%s_%d.png" % [PARTS_DIR, part[0], part[1], part[2] + 1])
		var layer := tex.get_image()
		if layer.is_compressed():
			layer.decompress()
		layer.convert(Image.FORMAT_RGBA8)
		img.blend_rect(layer, Rect2i(0, 0, 90, 110), Vector2i.ZERO)
	var head := img.get_region(HEAD_RECT)
	head.resize(ICON_SIZE.x, ICON_SIZE.y, Image.INTERPOLATE_CUBIC)
	# Crisp edges: every pixel is either solid or empty
	for y in head.get_height():
		for x in head.get_width():
			var p := head.get_pixel(x, y)
			head.set_pixel(x, y, Color(p, 1.0) if p.a > 0.45 else Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(head)
	_cache[key] = out
	return out
