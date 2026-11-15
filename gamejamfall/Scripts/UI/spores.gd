extends Control
## Drifting fungus spores: a few pale specks float across the screen, and more
## appear as more people are known to be infected (like the static and the music,
## it only counts infections the player can see). Drawn on whole game pixels.

const BASE_COUNT := 5            # Spores with nobody infected
const PER_INFECTED := 6          # Extra spores per infected resident
const MAX_COUNT := 40
const COLOR := Color(0.36, 0.44, 0.3)
const MAX_ALPHA := 0.8
const LIFETIME := Vector2(5.0, 10.0)   # Seconds each spore lives (min, max)

var _spores: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in _target_count():
		_spores.append(_new_spore(randf()))   # Start part-way through their lives


func _target_count() -> int:
	var infected := GameState.present_residents().filter(
		func(r): return r.known_status == Resident.Status.POSITIVE).size()
	return mini(BASE_COUNT + PER_INFECTED * infected, MAX_COUNT)


func _new_spore(age := 0.0) -> Dictionary:
	var life := randf_range(LIFETIME.x, LIFETIME.y)
	return {
		"pos": Vector2(randf() * size.x, randf() * size.y),
		"vel": Vector2(randf_range(-3.0, 3.0), randf_range(-2.5, 0.5)),   # Mostly drifting up
		"wobble": randf() * TAU,
		"life": life,
		"age": age * life,
		"big": randf() < 0.2,
	}


func _process(delta: float) -> void:
	var target := _target_count()
	for s in _spores:
		s.age += delta
		s.pos += s.vel * delta + Vector2(sin(s.age * 1.3 + s.wobble) * 2.0 * delta, 0)
	# Replace spores that died (only up to the current target, so they thin out gently)
	for i in range(_spores.size() - 1, -1, -1):
		if _spores[i].age >= _spores[i].life:
			_spores.remove_at(i)
	while _spores.size() < target:
		_spores.append(_new_spore())
	queue_redraw()


func _draw() -> void:
	for s in _spores:
		var t: float = s.age / s.life
		var a := MAX_ALPHA * minf(1.0, minf(t, 1.0 - t) * 4.0)   # Fade in and out
		var p: Vector2 = s.pos.floor()
		draw_rect(Rect2(p, Vector2(2, 1) if s.big else Vector2.ONE), Color(COLOR, a))
