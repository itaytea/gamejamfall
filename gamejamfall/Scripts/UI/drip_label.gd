extends Label
## A label whose letters drip: little drops gather under the text, hang for a
## moment, then fall away and fade. Used for "Infected" on the Command screen.
## Drops are 1 game pixel wide and move in whole pixels.

const SPAWN_EVERY := Vector2(0.5, 1.1)   # Seconds between new drops (random in range)
const MAX_DROPS := 3
const HANG_TIME := 1.2                   # Drop grows under the letter (1, 2, then 3 pixels)
const FALL_TIME := 0.6                   # Then falls and fades
const FALL_DISTANCE := 7.0

var _drops: Array[Dictionary] = []
var _next := 0.3


func _process(delta: float) -> void:
	_next -= delta
	if _next <= 0.0 and _drops.size() < MAX_DROPS:
		_next = randf_range(SPAWN_EVERY.x, SPAWN_EVERY.y)
		var width := _text_width()
		if width > 2:
			_drops.append({"x": floorf(randf_range(1, width - 1)), "t": 0.0})
	for d in _drops:
		d.t += delta
	_drops = _drops.filter(func(d): return d.t < HANG_TIME + FALL_TIME)
	queue_redraw()


func _text_width() -> float:
	return get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x


## Bottom of the letters, in this label's coordinates.
func _baseline() -> float:
	var font := get_theme_font("font")
	var fs := get_theme_font_size("font_size")
	var top := (size.y - font.get_height(fs)) / 2.0 if vertical_alignment == VERTICAL_ALIGNMENT_CENTER else 0.0
	return roundf(top + font.get_ascent(fs))


func _draw() -> void:
	var c := get_theme_color("font_color")
	var y0 := _baseline()
	for d in _drops:
		if d.t < HANG_TIME:
			# Hanging: grows from 1 to 3 pixels long
			var length := 1.0 + floorf(d.t / HANG_TIME * 3.0)
			draw_rect(Rect2(d.x, y0, 1, length), c)
		else:
			# Falling: a single pixel drops away and fades
			var k: float = (d.t - HANG_TIME) / FALL_TIME
			var y := y0 + 3.0 + floorf(k * FALL_DISTANCE)
			draw_rect(Rect2(d.x, y, 1, 1), Color(c, c.a * (1.0 - k)))
