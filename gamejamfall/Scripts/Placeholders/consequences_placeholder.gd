extends Control
## THROWAWAY: replace with the dialogue-driven night report.

func _ready() -> void:
	$VBoxContainer/Buttons/Continue.pressed.connect(GameState.end_stage)
	var lines: Array = GameState.events.map(func(e): return str(e))
	$VBoxContainer/Label.text = "NIGHT %d\n%s" % [GameState.day, "\n".join(PackedStringArray(lines))]
