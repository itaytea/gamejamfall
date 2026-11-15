extends Control
## Shown when the cure is synthesized. Play Again starts a new run.

func _ready() -> void:
	$Box/Text.text = "You synthesized the cure on day %d.\nThe nightmare is over." % GameState.day
	$Box/PlayAgain.pressed.connect(GameState.start_new_run)
