class_name Resident
extends RefCounted

#-- general values --

#status on farm
enum Status {UNKOWN, POSITIVE, NEGATIVE}
enum Task { IDLE, GUARD, GARDENER, FORAGER }

#possible names: waiting on sam to make list
const NAMES := ["Itay", "Darinah", "Sam", "Keira", "Cameron", "Joan", "Iwa", "August", "Kier", "Harini", "Breanna", "Kailey", "Audrey", "Claire", "Jared"]

# Move to balance.gd in the future
const DISEASE_DAYS := 3
const FORAGE_DAYS := 2
const PORTRAIT_COUNT := 6

# -- resident specific values --

#identity
var name : String
var portrait_id: int #for now, if drinah decides to have a randomized system itll be different

#sickness - hidden variables
var is_infected := false
var days_until_death:= -1 #-1 if healthy
var is_dead := false

#sickness - known variables
var known_status: Status = Status.UNKOWN
var tested_on_day := -1

#farm status
var days_on_farm := 0
var task: Task = Task.IDLE
var is_away := false
var forage_days_left := 0

#create new visitor
static func random(infect_chance: float) -> Resident:
	var r := Resident.new()
	r.name = NAMES.pick_random()
	r.portrait_id = randi() % PORTRAIT_COUNT
	if randf() < infect_chance:
		r.is_infected = true
		#has a chance to be a few days into the infection already
		r.days_until_death = randi_range(1, DISEASE_DAYS) 
	return r

# -- Disease functions --

#fresh infection
func infect() -> void:
	if is_infected or is_dead:
		return
	is_infected = true
	days_until_death = DISEASE_DAYS

#checks if person dies, called once a night
func tick_disease() -> bool:
	if not is_infected or is_dead:
		return false
	days_until_death -= 1
	if days_until_death <= 0:
		is_dead = true
		return true
	return false

#reveals pos or neg upon a test, script calling should spend the meal
func run_test(current_day: int) -> void:
	known_status = Status.POSITIVE if is_infected else Status.NEGATIVE
	tested_on_day = current_day

# -- Tasks --

#checks if person is alive and on farm
func is_present() -> bool:
	return not is_away and not is_dead

#assings task to person
func set_task(new_task: Task) -> void:
	return
