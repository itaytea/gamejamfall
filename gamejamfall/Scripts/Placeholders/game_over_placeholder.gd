extends Control
## THROWAWAY: replace with the real game over screen.

func _ready() -> void:
	$VBoxContainer/Buttons/Restart.pressed.connect(GameState.start_new_run)
	$VBoxContainer/Label.text = "GAME OVER\n%s\nSurvived %d days" % [GameState.lose_reason, GameState.day]
