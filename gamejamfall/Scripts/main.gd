extends Control
## Stays loaded the whole game. Swaps the current stage scene in StageHolder
## whenever GameState changes stage, and shows game over / the win screen.
## Every swap fades to black and back (FADE_TIME each way). Clicks are blocked
## while fading so nothing gets pressed twice.
## Main and StageHolder ignore the mouse, so clicks reach the dialogue boxes.

const FADE_TIME := 0.3

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


func _ready() -> void:
	# Connect BEFORE starting the run, or the first stage_changed is missed
	GameState.stage_changed.connect(_on_stage_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	_fade.color.a = 1.0          # Start black, fade in to the first scene
	GameState.start_new_run()


func _on_stage_changed(stage: int) -> void:
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


func _tween_fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished
