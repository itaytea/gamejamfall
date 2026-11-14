extends Control
## Stays loaded the whole game. Swaps the current stage scene in StageHolder
## whenever GameState changes stage, and shows game over when the run ends.
## To swap in real stage scenes later, just change the preload paths below.

@onready var holder: Control = $StageHolder

var _scenes := {
	GameState.Stage.ADMISSION: preload("res://Scenes/Placeholders/admission_placeholder.tscn"),
	GameState.Stage.COMMAND: preload("res://Scenes/Placeholders/command_placeholder.tscn"),
	GameState.Stage.CONSEQUENCES: preload("res://Scenes/Placeholders/consequences_placeholder.tscn"),
}
var _game_over_scene := preload("res://Scenes/Placeholders/game_over_placeholder.tscn")
var _current: Node


func _ready() -> void:
	# Connect BEFORE starting the run, or the first stage_changed is missed
	GameState.stage_changed.connect(_on_stage_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.start_new_run()


func _on_stage_changed(stage: int) -> void:
	_show(_scenes[stage].instantiate())


func _on_game_over(_reason: String, _days: int) -> void:
	_show(_game_over_scene.instantiate())


func _show(scene: Node) -> void:
	if _current:
		_current.queue_free()   # queue_free, not free: the button that triggered this is still running
	_current = scene
	holder.add_child(scene)
