extends ColorRect
## A night tint that the cursor lights up (Shaders/night_light.gdshader).
## Feeds the shader the mouse position in game pixels plus a short trail of
## where the cursor has just been. Put it on any full-screen ColorRect.

const TRAIL_LENGTH := 12
const TRAIL_SECONDS := 0.45      # How long the trail lingers
const TRAIL_STEP := 0.035        # Seconds between trail points

var _trail: Array = []           # [position, time]
var _since_step := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var mat := material as ShaderMaterial
	var now := Time.get_ticks_msec() / 1000.0
	var m := get_viewport().get_mouse_position().floor()
	_since_step += delta
	if _since_step >= TRAIL_STEP:
		_since_step = 0.0
		if _trail.is_empty() or _trail[0][0] != m:
			_trail.push_front([m, now])
	while not _trail.is_empty() and (now - _trail[-1][1] > TRAIL_SECONDS or _trail.size() > TRAIL_LENGTH):
		_trail.pop_back()
	var points := PackedVector2Array()
	var ages := PackedFloat32Array()
	for t in _trail:
		points.append(t[0])
		ages.append(clampf((now - t[1]) / TRAIL_SECONDS, 0.0, 1.0))
	while points.size() < TRAIL_LENGTH:
		points.append(Vector2(-100, -100))
		ages.append(1.0)
	mat.set_shader_parameter("mouse", m)
	mat.set_shader_parameter("has_mouse", Cursor._inside if Cursor else true)
	mat.set_shader_parameter("trail", points)
	mat.set_shader_parameter("trail_age", ages)
	mat.set_shader_parameter("trail_count", _trail.size())
