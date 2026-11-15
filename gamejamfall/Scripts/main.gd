extends Control
## Stays loaded the whole game. Swaps the current stage scene in StageHolder
## whenever GameState changes stage, and shows game over / the win screen.
## Every swap fades to black and back (FADE_TIME each way). Clicks are blocked
## while fading so nothing gets pressed twice.
## Main and StageHolder ignore the mouse, so clicks reach the dialogue boxes.

const FADE_TIME := 0.6
const DEATH_HOLD := 2.0        # Seconds of black while the death sound starts, before a night where someone died
const DEATH_EVENTS := ["died", "starved", "fight_killed", "forager_lost", "lab_lost"]

@onready var holder: Control = $StageHolder
@onready var _fade: ColorRect = $FadeLayer/Fade

var _scenes := {
	GameState.Stage.ADMISSION: preload("res://Scenes/Admission.tscn"),
	GameState.Stage.COMMAND: preload("res://Scenes/Command.tscn"),
	GameState.Stage.CONSEQUENCES: preload("res://Scenes/Consequences.tscn"),
}
var _game_over_scene := preload("res://Scenes/Placeholders/game_over_placeholder.tscn")
var _win_scene := preload("res://Scenes/Win.tscn")
var _current: Node
var _pending: Node            # Scene waiting to be shown once the screen is black
var _fading := false
var _death_hold := false      # Next fade holds on black with the death sound


func _ready() -> void:
	# Connect BEFORE starting the run, or the first stage_changed is missed
	GameState.stage_changed.connect(_on_stage_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	_fade.color.a = 1.0          # Start black, fade in to the first scene
	GameState.start_new_run()


func _on_stage_changed(stage: int) -> void:
	if stage == GameState.Stage.CONSEQUENCES:
		_death_hold = GameState.events.any(func(e): return e.type in DEATH_EVENTS)
	_show(_scenes[stage].instantiate())


func _on_game_over(_reason: String, _days: int) -> void:
	_show(_game_over_scene.instantiate())


func _on_game_won(_day: int) -> void:
	_show(_win_scene.instantiate())


## Queue a scene. If a fade is already running, the newest request wins.
func _show(scene: Node) -> void:
	if _pending:
		_pending.free()          # Never entered the tree, so free() is safe
	_pending = scene
	if not _fading:
		_transition()


func _transition() -> void:
	_fading = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP     # Block clicks during the fade
	if _current:                                         # First scene: already black
		await _tween_fade(1.0)
	if _death_hold:                                      # Someone died tonight: hold on black
		_death_hold = false
		Sfx.play("death")
		await get_tree().create_timer(DEATH_HOLD).timeout
	while _pending:
		if _current:
			_current.queue_free()
		_current = _pending
		_pending = null
		holder.add_child(_current)
	await _tween_fade(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fading = false
	if _pending:                                         # Something arrived during fade-in
		_transition()


## Fade to black, run `swap` while the screen is black, fade back in.
## Used inside a stage (e.g. between visitors). Clicks are blocked meanwhile.
## If a stage swap is already fading, just runs `swap` straight away.
func fade_through(swap: Callable) -> void:
	if _fading:
		swap.call()
		return
	_fading = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _tween_fade(1.0)
	swap.call()
	await _tween_fade(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fading = false
	if _pending:                                         # A stage swap arrived meanwhile
		_transition()


func _tween_fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished
