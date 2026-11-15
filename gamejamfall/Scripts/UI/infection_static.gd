extends ColorRect
## Faint TV static over the whole game once someone on the farm is known to be
## infected, getting stronger with each infected person (Shaders/tv_static.gdshader).
## Like the music, it only counts infections the player can see (status Infected),
## so it never gives away a hidden case.

const PER_INFECTED := 0.025      # Extra strength for each infected person
const FIRST := 0.03              # Strength with one infected person
const MAX_INTENSITY := 0.14
const FADE_SECONDS := 1.5

var _target := 0.0
var _intensity := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.residents_changed.connect(_update_target)
	GameState.stage_changed.connect(_update_target.unbind(1))
	_update_target()


func _update_target() -> void:
	var infected := GameState.present_residents().filter(
		func(r): return r.known_status == Resident.Status.POSITIVE).size()
	_target = 0.0 if infected == 0 else minf(FIRST + PER_INFECTED * (infected - 1), MAX_INTENSITY)


func _process(delta: float) -> void:
	_intensity = move_toward(_intensity, _target, delta * MAX_INTENSITY / FADE_SECONDS)
	(material as ShaderMaterial).set_shader_parameter("intensity", _intensity)
	visible = _intensity > 0.0
