extends Control
## THROWAWAY: replace with the real door scene.

func _ready() -> void:
	$VBoxContainer/Buttons/AdmitAll.pressed.connect(_admit_all)
	$VBoxContainer/Buttons/Done.pressed.connect(GameState.end_stage)
	var names: Array = GameState.visitors.map(func(v): return v.debug_text())
	$VBoxContainer/Label.text = "DAY %d - DOOR  Meals: %d\n%s" % [GameState.day, GameState.meals, "\n".join(PackedStringArray(names))]


func _admit_all() -> void:
	for v in GameState.visitors.duplicate():
		GameState.admit_visitor(v)
	GameState.end_stage()
