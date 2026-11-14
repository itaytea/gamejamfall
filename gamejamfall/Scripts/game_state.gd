extends Node
# this script is responsible for the gameplay loop. UI elements will call it

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

var residents: Array[Resident] = [] #includes people who are away, excludes player
var visitors: Array[Resident] = [] #today's visitor
var current_stage: Stage = Stage.COMMAND
var events: Array[Dictionary] = [] #tonight's events in order
var is_over := false
var lose_reason := ""

var _skip_admission := false #when nobody guards
var _garden_yield_override := -1 #special event, -1 = normal harvest yield
