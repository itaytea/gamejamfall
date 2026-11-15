extends Label
## A label whose word "infected" drips: little drops gather under it, hang for a
## moment, then fall away and fade. Other text in the label doesn't drip, so any
## status label can use this script. Drops are 1 game pixel wide, in whole pixels.

const SPAWN_EVERY := Vector2(0.5, 1.1)   # Seconds between new drops (random in range)
const MAX_DROPS := 3
const HANG_TIME := 1.2                   # Drop grows under the letter (1, 2, then 3 pixels)
const FALL_TIME := 0.6                   # Then falls and fades
const FALL_DISTANCE := 7.0

static var _word := RegEx.create_from_string("(?i)\\binfected\\b")

var _drops: Array[Dictionary] = []
var _next := 0.3


func _process(delta: float) -> void:
	_next -= delta
	if _next <= 0.0 and _drops.size() < MAX_DROPS:
		_next = randf_range(SPAWN_EVERY.x, SPAWN_EVERY.y)
		var span := _word_span()
		if span.y - span.x > 2:
			_drops.append({"x": floorf(randf_range(span.x + 1, span.y - 1)), "t": 0.0})
	for d in _drops:
		d.t += delta
	_drops = _drops.filter(func(d): return d.t < HANG_TIME + FALL_TIME)
	queue_redraw()


func _width_of(s: String) -> float:
	return get_theme_font("font").get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x


## Where "infected" sits in this label, as (left, right) x. (0, 0) if it isn't there.
func _word_span() -> Vector2:
	var m := _word.search(text)
	if m == null:
		return Vector2.ZERO
	var start := 0.0
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER: start = (size.x - _width_of(text)) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT: start = size.x - _width_of(text)
	var left := start + _width_of(text.substr(0, m.get_start()))
	return Vector2(left, left + _width_of(m.get_string()))


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
