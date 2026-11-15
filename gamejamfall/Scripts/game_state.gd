extends Node

enum Stage { ADMISSION, COMMAND, CONSEQUENCES }

signal meals_changed(meals: int)
signal residents_changed
signal visitors_changed
signal stage_changed(stage: Stage)
signal day_advanced(day: int)
signal game_over(reason: String, days_survived: int)
signal game_won(day: int)

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

# Cure
var research := 0.0                   # Hidden from the player: 0-100
var has_chemicals := false            # Brought back from the lab
var synth_nights := 0                 # Nights in a row the same person has synthesized
var is_won := false
var _synth_resident: Resident = null

# Rationing: when tonight's food can't feed everyone, the night pauses and the
# night report asks the player who goes without (see resolve_ration)
var awaiting_ration := false
var ration_short := 0                 # How many residents can't be fed tonight

var _skip_admission := false          # Set when nobody guarded last night
var _garden_yield_override := -1      # Set by events; -1 = normal yield


# ================================================================ Run setup

func start_new_run() -> void:
	day = 1
	meals = 2
	residents.clear()
	visitors.clear()
	events.clear()
	is_over = false
	lose_reason = ""
	_skip_admission = false
	research = 0.0
	has_chemicals = false
	synth_nights = 0
	is_won = false
	_synth_resident = null
	awaiting_ration = false
	ration_short = 0
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
			if is_won:
				game_won.emit(day)
			elif is_over:
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
		visitors.append(_make_person(visitor_infect_chance()))
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
	return meals >= Balance.TEST_COST and r.can_be_tested()


## Door scene: if this returns true, play the visitor's "tested" cue.
func test_visitor(r: Resident) -> bool:
	if not can_test(r):
		return false
	meals -= Balance.TEST_COST
	r.run_test()
	visitors_changed.emit()
	return true


## Residents can be retested any time (results can be wrong, and foragers can bring it home),
## except people already known to be infected: a positive result is always right.
func can_test_resident(r: Resident) -> bool:
	return meals >= Balance.TEST_COST and r.is_present() and r.known_status != Resident.Status.POSITIVE


func test_resident(r: Resident) -> bool:
	if not can_test_resident(r):
		return false
	meals -= Balance.TEST_COST
	r.run_test()
	residents_changed.emit()
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


## D: visitors are more likely to be infected the longer the outbreak goes on.
func visitor_infect_chance() -> float:
	return minf(Balance.VISITOR_INFECT_CHANCE + (day - 1) * Balance.VISITOR_INFECT_CHANCE_PER_DAY, Balance.INFECT_CHANCE_CAP)


## C: only GARDEN_PLOTS gardeners produce; any extra gardeners make nothing.
func productive_gardeners() -> int:
	var gardeners := residents.filter(func(r): return r.is_present() and r.task == Resident.Task.GARDENER).size()
	return mini(gardeners, Balance.GARDEN_PLOTS)


## Tasks this resident can be given right now. Lab and Synthesize only appear once
## unlocked, and only one person at a time can hold each.
func available_tasks(r: Resident) -> Array:
	var tasks := [Resident.Task.IDLE, Resident.Task.GUARD, Resident.Task.GARDENER,
		Resident.Task.FORAGER, Resident.Task.RESEARCHER]
	if research >= 100.0 and not has_chemicals and not _someone_else_on(Resident.Task.LAB, r):
		tasks.append(Resident.Task.LAB)
	if has_chemicals and not _someone_else_on(Resident.Task.SYNTHESIZER, r):
		tasks.append(Resident.Task.SYNTHESIZER)
	return tasks


func _someone_else_on(task: Resident.Task, r: Resident) -> bool:
	return residents.any(func(o): return o != r and o.task == task)


func has_guard() -> bool:
	return residents.any(func(r): return r.is_present() and r.task == Resident.Task.GUARD)


## Guaranteed food tomorrow morning: gardens minus mouths. Ignores foragers and events.
func projected_meals() -> int:
	var leaving := residents.filter(func(r): return r.is_present() and _is_trip(r.task)).size()
	var mouths := present_residents().size() - leaving + 1
	return meals + productive_gardeners() * Balance.GARDEN_YIELD - mouths * Balance.MEALS_PER_PERSON


# ================================================================ The night

func _resolve_night() -> void:
	events.clear()

	# 0. Foragers and the lab-goer set off now (they don't eat at home tonight)
	for r in residents:
		if r.is_present() and _is_trip(r.task):
			r.depart()

	# 1. Random event (may modify the steps below)
	_roll_event()

	# 2. Gardens, as one combined event. Only GARDEN_PLOTS gardeners produce (C).
	var yield_per := _garden_yield_override if _garden_yield_override >= 0 else Balance.GARDEN_YIELD
	var gardeners := productive_gardeners()
	if gardeners > 0:
		meals += gardeners * yield_per
		_event("garden", {"gardeners": gardeners, "amount": gardeners * yield_per})

	# 2b. Research: each researcher adds a hidden random amount. A line per researcher, then how it feels.
	var researchers := residents.filter(func(r): return r.is_present() and r.task == Resident.Task.RESEARCHER)
	if not researchers.is_empty():
		var was_done := research >= 100.0
		for r in researchers:
			research = minf(research + randf_range(Balance.RESEARCH_MIN, Balance.RESEARCH_MAX), 100.0)
			_event("researched", {"name": r.name})
		_event(_research_cue(was_done))

	# 3. Travellers coming home. is_dead here reflects earlier nights, since the disease ticks below.
	#    B: even healthy travellers can die on the road.
	for r in residents.duplicate():
		if r.is_away and r.tick_forage():
			var is_lab: bool = r.task == Resident.Task.LAB
			var death_chance := Balance.LAB_DEATH_CHANCE if is_lab else Balance.FORAGE_DEATH_CHANCE
			if r.is_dead or randf() < death_chance:
				residents.erase(r)
				_event("lab_lost" if is_lab else "forager_lost", {"name": r.name})
			elif is_lab:
				has_chemicals = true
				r.return_home()
				_event("lab_returned", {"name": r.name})
			else:
				var found := randi_range(Balance.FORAGE_MIN, Balance.FORAGE_MAX)
				meals += found
				r.return_home()
				_event("forager_returned", {"name": r.name, "amount": found})

	# 3b. Hidden attributes: greedy residents take food, belligerent ones start fights,
	#     and sometimes someone points a finger (truthfully or not)
	var thieves := _greedy_night()
	var brawlers := _fight_night()
	_tattle_night(thieves, brawlers)

	# 4. Eating. The player eats first. If what's left can't feed every resident,
	#    pause here: the night report asks the player who goes without, then calls
	#    resolve_ration(), which finishes the night. (No food even for the player: game over.)
	var mouths := present_residents().size()
	var can_feed := (meals - Balance.MEALS_PER_PERSON) / Balance.MEALS_PER_PERSON
	if meals >= Balance.MEALS_PER_PERSON and can_feed < mouths:
		ration_short = mouths - maxi(can_feed, 0)
		awaiting_ration = true
		_event("ration_needed", {"count": ration_short})
		return
	_finish_night([])


## Called by the night report once the player has picked exactly ration_short
## residents to go without food. They starve; then the rest of the night plays out.
func resolve_ration(unfed: Array) -> void:
	if not awaiting_ration:
		return
	awaiting_ration = false
	ration_short = 0
	_finish_night(unfed)


func _finish_night(unfed: Array) -> void:
	# 4. Eating (continued): everyone fed, plus the player
	var fed := present_residents().filter(func(r): return not r in unfed).size()
	var eaten := (fed + 1) * Balance.MEALS_PER_PERSON
	meals -= eaten
	_event("eaten", {"amount": eaten, "left": maxi(meals, 0)})

	# 4b. Starvation: whoever went without dies. Like a fight death, they only
	#     spread the disease if they were sick (a superspreader infects two).
	for r in unfed:
		if not r in residents:
			continue
		r.is_dead = true
		residents.erase(r)
		_event("starved", {"name": r.name})
		if r.is_infected:
			var spreads := Balance.SUPERSPREADER_INFECTS if r.attribute == Resident.Attribute.SUPERSPREADER else 1
			for i in spreads:
				var victim := _random_healthy()
				if victim == null:
					break
				victim.infect()
				_event("infected", {"name": victim.name, "from": r.name})

	# 5. Disease. Collect deaths first, then infect, so nobody infected tonight also ticks tonight.
	var died_on_farm: Array[Resident] = []
	for r in residents.duplicate():
		if r.tick_disease() and not r.is_away:   # Deaths while away stay hidden until due back
			residents.erase(r)
			died_on_farm.append(r)
			_event("died", {"name": r.name})

	for dead in died_on_farm:
		var spreads := Balance.SUPERSPREADER_INFECTS if dead.attribute == Resident.Attribute.SUPERSPREADER else 1
		for i in spreads:
			var victim := _random_healthy()
			if victim == null:
				break
			victim.infect()
			_event("infected", {"name": victim.name, "from": dead.name})

	# 6. Time on farm
	for r in residents:
		if r.is_present():
			r.days_on_farm += 1

	# 6b. Synthesis: the same person, SYNTH_NIGHTS nights in a row, surviving each night.
	#     Anyone who died tonight is already gone, so their night doesn't count.
	var synth: Resident = null
	for r in residents:
		if r.is_present() and r.task == Resident.Task.SYNTHESIZER:
			synth = r
			break
	if has_chemicals and synth != null:
		if synth != _synth_resident:
			if synth_nights > 0:
				_event("synthesis_interrupted")
			synth_nights = 0
			_synth_resident = synth
		synth_nights += 1
		_event("synthesizing", {"name": synth.name, "nights": synth_nights, "total": Balance.SYNTH_NIGHTS})
		if synth_nights >= Balance.SYNTH_NIGHTS:
			is_won = true
			_event("cure_done", {"name": synth.name})
			residents_changed.emit()
			return
	else:
		if synth_nights > 0:
			_event("synthesis_interrupted")
		synth_nights = 0
		_synth_resident = null

	residents_changed.emit()

	# 7. Lose checks. game_over is emitted after the report plays (see end_stage).
	if meals < 0:
		_lose("lost_starved", "The food ran out.")
		return
	if residents.is_empty():   # Includes foragers who are away, since they may come home
		_lose("lost_alone", "You are the last one standing.")
		return

	# 8. Farm full: no one can be let in, so tomorrow's door is skipped (and no one slips in)
	if is_farm_full():
		_skip_admission = true
		if not has_guard():
			_event("no_guard")
		_event("farm_full")
	# 9. No guard: people slip in overnight, and tomorrow's admission is skipped
	elif not has_guard():
		_forced_entry()


# ================================================================ Hidden attributes

func _random_healthy() -> Resident:
	var healthy := residents.filter(func(r): return r.is_present() and not r.is_infected)
	return null if healthy.is_empty() else healthy.pick_random()


## Greedy: food goes missing. The report never says who took it.
## Returns the residents who stole tonight (for the tattletale).
func _greedy_night() -> Array:
	var stolen := 0
	var thieves := []
	for r in residents:
		if r.is_present() and r.attribute == Resident.Attribute.GREEDY and randf() < Balance.GREEDY_STEAL_CHANCE:
			var take := mini(randi_range(Balance.GREEDY_STEAL_MIN, Balance.GREEDY_STEAL_MAX), maxi(meals - stolen, 0))
			if take > 0:
				stolen += take
				thieves.append(r)
	if stolen > 0:
		meals -= stolen
		_event("food_stolen", {"amount": stolen})
	return thieves


## Belligerent: a fight with another resident at home. If the other person survives,
## the report names both (in random order, so it doesn't give away who started it).
## If they die, it's clear who did it. A sick victim infects their killer, and a sick
## superspreader victim also infects one more person.
## Returns [attacker, victim] pairs for fights where nobody died (for the tattletale).
func _fight_night() -> Array:
	var survived := []
	for attacker in residents.duplicate():
		if not attacker.is_present() or attacker.attribute != Resident.Attribute.BELLIGERENT:
			continue
		if randf() >= Balance.FIGHT_CHANCE:
			continue
		var others := residents.filter(func(o): return o != attacker and o.is_present())
		if others.is_empty():
			continue
		var victim: Resident = others.pick_random()
		if randf() >= Balance.FIGHT_KILL_CHANCE:
			var pair := [attacker.name, victim.name]
			pair.shuffle()
			_event("fight", {"a": pair[0], "b": pair[1]})
			survived.append([attacker, victim])
			continue
		victim.is_dead = true
		residents.erase(victim)
		_event("fight_killed", {"name": victim.name, "killer": attacker.name})
		if victim.is_infected:
			if not attacker.is_infected:
				attacker.infect()
				_event("infected_by_fight", {"name": attacker.name, "from": victim.name})
			if victim.attribute == Resident.Attribute.SUPERSPREADER:
				var bystander := _random_healthy()
				if bystander != null:
					bystander.infect()
					_event("infected_bystander", {"name": bystander.name, "from": victim.name})
	return survived


## Tattletale: after a theft or a survived fight, someone may accuse someone.
## Truthful: a bystander names the culprit. Lie: the culprit names an innocent person.
## Either way the culprit is one of the two names, which is the player's clue.
func _tattle_night(thieves: Array, brawlers: Array) -> void:
	var incidents := []
	for t in thieves:
		incidents.append({"kind": "theft", "culprit": t, "victim": null})
	for pair in brawlers:
		incidents.append({"kind": "fight", "culprit": pair[0], "victim": pair[1]})
	if incidents.is_empty() or randf() >= Balance.TATTLE_CHANCE:
		return
	var incident: Dictionary = incidents.pick_random()
	var culprit: Resident = incident.culprit
	if not culprit.is_present():
		return
	var accuser: Resident
	var accused: Resident
	if randf() < Balance.TATTLE_TRUTH_CHANCE:
		# Someone else saw it. In a fight, the victim knows best who started it.
		var witnesses := residents.filter(func(o): return o != culprit and o.is_present())
		if witnesses.is_empty():
			return
		accuser = incident.victim if incident.victim != null and incident.victim.is_present() and randf() < 0.5 else witnesses.pick_random()
		accused = culprit
	else:
		# The culprit points the finger elsewhere. In a fight, at the other person.
		var innocents := residents.filter(func(o): return o != culprit and o.is_present())
		if innocents.is_empty():
			return
		accuser = culprit
		accused = incident.victim if incident.victim != null and incident.victim.is_present() else innocents.pick_random()
	_event("tattle_" + incident.kind, {"accuser": accuser.name, "accused": accused.name})


func _is_trip(task: Resident.Task) -> bool:
	return task == Resident.Task.FORAGER or task == Resident.Task.LAB


## Which progress message plays after tonight's research.
func _research_cue(was_done: bool) -> String:
	if research >= 100.0:
		return "research_ready" if was_done else "research_breakthrough"
	if research >= 75.0:
		return "research_75"
	if research >= 50.0:
		return "research_50"
	if research >= 25.0:
		return "research_25"
	return "research_0"


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
		var r := _make_person(maxf(Balance.NO_GUARD_INFECT_CHANCE, visitor_infect_chance()))
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
