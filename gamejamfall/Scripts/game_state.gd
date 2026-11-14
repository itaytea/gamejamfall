extends Node

enum Stage { ADMISSION, COMMAND, CONSEQUENCES }

signal meals_changed(meals: int)
signal residents_changed
signal visitors_changed
signal stage_changed(stage: Stage)
signal day_advanced(day: int)
signal game_over(reason: String, days_survived: int)

var day := 1
var meals := 0:
	set(value):
		meals = value
		meals_changed.emit(meals)

var residents: Array[Resident] = []   # Includes foragers who are away. The player is not in here.
var visitors: Array[Resident] = []    # Today's people at the door
var current_stage: Stage = Stage.COMMAND
var events: Array[Dictionary] = []    # Tonight's events, in order. Each has a "type" key.
var is_over := false
var lose_reason := ""

var _skip_admission := false          # Set when nobody guarded last night
var _garden_yield_override := -1      # Set by events; -1 = normal yield


# ================================================================ Run setup

func start_new_run() -> void:
	day = 1
	meals = 0
	residents.clear()
	visitors.clear()
	events.clear()
	is_over = false
	lose_reason = ""
	_skip_admission = false
	for i in 2:
		var r := _make_person(0.0)                 # Guaranteed healthy...
		r.known_status = Resident.Status.NEGATIVE  # ...and the player knows it
		residents.append(r)
	residents_changed.emit()
	day_advanced.emit(day)
	_set_stage(Stage.COMMAND)


# ================================================================ Stage flow

## Called by each stage scene when it's finished
## (door empty, End Day pressed, report dialogue done).
func end_stage() -> void:
	match current_stage:
		Stage.ADMISSION:
			visitors.clear()          # Anyone not admitted is turned away
			visitors_changed.emit()
			_set_stage(Stage.COMMAND)
		Stage.COMMAND:
			_resolve_night()
			_set_stage(Stage.CONSEQUENCES)   # The report plays even on a loss
		Stage.CONSEQUENCES:
			if is_over:
				game_over.emit(lose_reason, day)
			else:
				_start_day()


func _start_day() -> void:
	day += 1
	day_advanced.emit(day)
	if _skip_admission:
		_skip_admission = false
		_set_stage(Stage.COMMAND)
		return
	visitors.clear()
	for i in randi_range(Balance.VISITORS_MIN, Balance.VISITORS_MAX):
		visitors.append(_make_person(Balance.VISITOR_INFECT_CHANCE))
	visitors_changed.emit()
	_set_stage(Stage.ADMISSION)


func _set_stage(stage: Stage) -> void:
	current_stage = stage
	stage_changed.emit(stage)


# ================================================================ Player actions
# Each returns true if it happened, so the UI can react (shake, sound, dialogue).

func is_farm_full() -> bool:
	return residents.size() >= Balance.MAX_RESIDENTS


func can_test(r: Resident) -> bool:
	return meals >= Balance.TEST_COST and r.known_status == Resident.Status.UNKNOWN


## Door scene: if this returns true, play the visitor's "tested" cue.
func test_visitor(r: Resident) -> bool:
	if not can_test(r):
		return false
	meals -= Balance.TEST_COST
	r.run_test()
	visitors_changed.emit()
	return true


func admit_visitor(r: Resident) -> bool:
	if is_farm_full():
		return false
	visitors.erase(r)
	residents.append(r)
	visitors_changed.emit()
	residents_changed.emit()
	return true


## Door scene: play the visitor's "rejected" cue first, then call this.
func turn_away(r: Resident) -> void:
	visitors.erase(r)
	visitors_changed.emit()


func assign_task(r: Resident, task: Resident.Task) -> void:
	r.set_task(task)
	residents_changed.emit()


func can_exile(r: Resident) -> bool:
	return meals >= Balance.EXILE_COST and r.is_present()


func exile(r: Resident) -> bool:
	if not can_exile(r):
		return false
	meals -= Balance.EXILE_COST
	residents.erase(r)
	residents_changed.emit()
	return true


# ================================================================ Helpers for UI

func present_residents() -> Array:
	return residents.filter(func(r): return r.is_present())


func has_guard() -> bool:
	return residents.any(func(r): return r.is_present() and r.task == Resident.Task.GUARD)


## Guaranteed food tomorrow morning: gardens minus mouths. Ignores foragers and events.
func projected_meals() -> int:
	var gardeners := residents.filter(func(r): return r.is_present() and r.task == Resident.Task.GARDENER).size()
	var mouths := present_residents().size() + 1
	return meals + gardeners * Balance.GARDEN_YIELD - mouths * Balance.MEALS_PER_PERSON


# ================================================================ The night

func _resolve_night() -> void:
	events.clear()

	# 1. Random event (may modify the steps below)
	_roll_event()

	# 2. Gardens, as one combined event
	var yield_per := _garden_yield_override if _garden_yield_override >= 0 else Balance.GARDEN_YIELD
	var gardeners := 0
	for r in residents:
		if r.is_present() and r.task == Resident.Task.GARDENER:
			gardeners += 1
	if gardeners > 0:
		meals += gardeners * yield_per
		_event("garden", {"gardeners": gardeners, "amount": gardeners * yield_per})

	# 3. Foragers. is_dead here reflects earlier nights, since the disease ticks below.
	for r in residents.duplicate():
		if r.is_away and r.tick_forage():
			if r.is_dead:
				residents.erase(r)
				_event("forager_lost", {"name": r.name})
			else:
				var found := randi_range(Balance.FORAGE_MIN, Balance.FORAGE_MAX)
				meals += found
				r.return_home()
				_event("forager_returned", {"name": r.name, "amount": found})

	# 4. Eating: everyone present, plus the player
	var eaten := (present_residents().size() + 1) * Balance.MEALS_PER_PERSON
	meals -= eaten
	_event("eaten", {"amount": eaten, "left": maxi(meals, 0)})

	# 5. Disease. Collect deaths first, then infect, so nobody infected tonight also ticks tonight.
	var died_on_farm: Array[Resident] = []
	for r in residents.duplicate():
		if r.tick_disease() and not r.is_away:   # Deaths while away stay hidden until due back
			residents.erase(r)
			died_on_farm.append(r)
			_event("died", {"name": r.name})

	for dead in died_on_farm:
		var healthy := residents.filter(func(r): return r.is_present() and not r.is_infected)
		if healthy.is_empty():
			continue
		var victim: Resident = healthy.pick_random()
		victim.infect()
		_event("infected", {"name": victim.name, "from": dead.name})

	# 6. Time on farm
	for r in residents:
		if r.is_present():
			r.days_on_farm += 1

	residents_changed.emit()

	# 7. Lose checks. game_over is emitted after the report plays (see end_stage).
	if meals < 0:
		_lose("lost_starved", "The food ran out.")
		return
	if residents.is_empty():   # Includes foragers who are away, since they may come home
		_lose("lost_alone", "You are the last one standing.")
		return

	# 8. No guard: people slip in overnight, and tomorrow's admission is skipped
	if not has_guard():
		_forced_entry()


func _roll_event() -> void:
	_garden_yield_override = -1
	if randf() >= Balance.EVENT_CHANCE:
		return
	# Phase 7: replace with a weighted pick from an event list.
	var any_gardener := residents.any(func(r): return r.is_present() and r.task == Resident.Task.GARDENER)
	if any_gardener:
		_garden_yield_override = Balance.POOR_HARVEST_YIELD
		_event("poor_harvest", {"amount": Balance.POOR_HARVEST_YIELD})


func _forced_entry() -> void:
	_skip_admission = true
	_event("no_guard")
	for i in randi_range(Balance.VISITORS_MIN, Balance.VISITORS_MAX):
		if is_farm_full():
			break
		var r := _make_person(Balance.NO_GUARD_INFECT_CHANCE)
		residents.append(r)
		_event("slipped_in", {"name": r.name})
	residents_changed.emit()


func _lose(event_type: String, reason: String) -> void:
	is_over = true
	lose_reason = reason
	_event(event_type)


# ================================================================ Internals

## Resident.random(), but rerolls the name so nobody shares one with someone here.
func _make_person(infect_chance: float) -> Resident:
	var r := Resident.random(infect_chance)
	var taken := (residents + visitors).map(func(p): return p.name)
	for attempt in 10:
		if r.name not in taken:
			break
		r.name = Resident.NAMES.pick_random()
	return r


func _event(type: String, data := {}) -> void:
	data["type"] = type
	events.append(data)
	print("[Day %d] %s" % [day, data])   # Lets you play the loop from the Output panel
