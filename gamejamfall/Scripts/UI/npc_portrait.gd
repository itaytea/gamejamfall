extends Control
## A visitor/resident drawn from the artist's modular parts (Sprites/npc modes/),
## stacked body > face > clothes > hair on the same 90x110 canvas as the original
## example sprite, so the alignment matches. Each part is picked by the resident's
## base_id / face_id / clothes_id / hair_id (0-based; the files are numbered from 1).
## The shadow is the same four parts flattened first (CanvasGroup), then darkened,
## so overlapping parts don't make darker patches.

const PARTS_DIR := "res://Sprites/npc modes/"

@onready var _layers := [$Body/Base, $Body/Face, $Body/Clothes, $Body/Hair]
@onready var _shadow_layers := [$Shadow/Base, $Shadow/Face, $Shadow/Clothes, $Shadow/Hair]


func show_resident(r: Resident) -> void:
	var textures := [
		_part("BASE", "npc_base", r.base_id),
		_part("FACE", "npc_face", r.face_id),
		_part("CLOTHES", "npc_clothes", r.clothes_id),
		_part("HAIR", "npc_hair", r.hair_id),
	]
	for i in textures.size():
		_layers[i].texture = textures[i]
		_shadow_layers[i].texture = textures[i]


func _part(folder: String, prefix: String, id: int) -> Texture2D:
	return load("%s%s/%s_%d.png" % [PARTS_DIR, folder, prefix, id + 1])
