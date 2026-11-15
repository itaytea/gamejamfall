extends Control
## Night report: plays each of tonight's events (GameState.events) as dialogue,
## one after another, then moves on (next day, or game over).
## Each event's "type" is a cue in Dialogue/report.dialogue.
## If there isn't enough food, the report pauses and asks who goes without
## (the Ration panel), then plays the rest of the night.

const REPORT_DIALOGUE: DialogueResource = preload("res://Dialogue/report.dialogue")
const TASK_NAMES: Dictionary = preload("res://Scripts/command.gd").TASK_NAMES

# Ration rows: NAME | INFECTED? | TONIGHT (see ResidentRows for the colours)
const ROW_COLS := [58, 50, 50]
const COLOR_CHOSEN := Color(0.62, 0.16, 0.14)

@onready var _title: Label = $Box/Title
@onready var _dialogue: Control = $Box/DialogueBox
@onready var _box: Control = $Box
@onready var _ration: Control = $Ration
@onready var _ration_title: Label = $Ration/Title
@onready var _ration_list: VBoxContainer = $Ration/List
@onready var _ration_confirm: Button = $Ration/Confirm

var _unfed: Array = []
signal _ration_chosen


func _ready() -> void:
	_title.text = "NIGHT %d" % GameState.day
	_ration.hide()
	_ration_confirm.pressed.connect(_on_ration_confirm)
	_play_report()


func _play_report() -> void:
	var i := 0
	while true:
		while i < GameState.events.size():
			await _dialogue.play(REPORT_DIALOGUE, GameState.events[i].type, [GameState.events[i]])
			i += 1
		if not GameState.awaiting_ration:
			break
		await _choose_unfed()   # Adds the rest of the night's events, then keep playing
	GameState.end_stage()


func _choose_unfed() -> void:
	_unfed.clear()
	for child in _ration_list.get_children():
		_ration_list.remove_child(child)
		child.queue_free()
	for r in GameState.present_residents():
		_ration_list.add_child(_ration_row(r))
	_refresh_ration()
	_box.hide()
	_ration.show()
	await _ration_chosen
	_ration.hide()
	_box.show()
	GameState.resolve_ration(_unfed.duplicate())


## One toggle button per resident, with three label columns inside it:
## name, what the player knows about their infection, and what they're doing tonight.
func _ration_row(r: Resident) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size.y = ResidentRows.ROW_HEIGHT
	b.add_child(ResidentRows.columns([r.name, r.status_text(), _tonight_text(r)], ROW_COLS))
	_color_row(b, r)
	b.toggled.connect(_on_ration_toggled.bind(r, b))
	return b


## Tonight's task. Anyone who came home from a trip tonight is shown as just back
## (return_home() already set them to Idle).
func _tonight_text(r: Resident) -> String:
	for e in GameState.events:
		if e.get("name", "") == r.name:
			if e.type == "forager_returned": return "Back from road"
			if e.type == "lab_returned": return "Back from lab"
	return TASK_NAMES.get(r.task, "Idle")


## Chosen rows turn red; otherwise the status column keeps its infection colour.
func _color_row(b: Button, r: Resident) -> void:
	ResidentRows.color_row(b.get_child(0), r, COLOR_CHOSEN if r in _unfed else null)


func _on_ration_toggled(on: bool, r: Resident, b: Button) -> void:
	if on and not r in _unfed:
		_unfed.append(r)
	elif not on:
		_unfed.erase(r)
	_color_row(b, r)
	_refresh_ration()


## The button shows how many are picked (e.g. 0/2) until it's exactly enough,
## then turns into CONFIRM.
func _refresh_ration() -> void:
	_ration_title.text = "WHO GOES WITHOUT?"
	var enough := _unfed.size() == GameState.ration_short
	_ration_confirm.disabled = not enough
	_ration_confirm.text = "CONFIRM" if enough else "%d/%d" % [_unfed.size(), GameState.ration_short]


func _on_ration_confirm() -> void:
	if _unfed.size() == GameState.ration_short:
		_ration_chosen.emit()
