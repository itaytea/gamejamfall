extends Control
## THROWAWAY: replace with the real command menu.

func _ready() -> void:
	$VBoxContainer/Buttons/AutoAssign.pressed.connect(_auto_assign)
	$VBoxContainer/Buttons/NoGuard.pressed.connect(_no_guard)
	$VBoxContainer/Buttons/EndDay.pressed.connect(GameState.end_stage)
	_refresh()


## 1st person guards, 2nd gardens, the rest alternate forager / gardener.
func _auto_assign() -> void:
	var people: Array = GameState.present_residents()
	for i in people.size():
		var task := Resident.Task.GARDENER
		if i == 0:
			task = Resident.Task.GUARD
		elif i >= 2 and i % 2 == 0:
			task = Resident.Task.FORAGER
		GameState.assign_task(people[i], task)
	_refresh()


## Everyone gardens, nobody guards: tests people slipping in overnight.
func _no_guard() -> void:
	for r in GameState.present_residents():
		GameState.assign_task(r, Resident.Task.GARDENER)
	_refresh()


func _refresh() -> void:
	var lines: Array = GameState.residents.map(func(r): return r.debug_text())
	$VBoxContainer/Label.text = "DAY %d - COMMAND  Meals: %d (-> %d)\n%s" % [
		GameState.day, GameState.meals, GameState.projected_meals(), "\n".join(PackedStringArray(lines))]
