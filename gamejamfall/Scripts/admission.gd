extends Control
## Admission stage: visitors come to the door one at a time.
## Test (costs a meal), Admit (free, if there's room) or Deny.
## Layout follows Sprites/ADMIT SCREEN REFERENCE.png.

const VISITOR_DIALOGUE: DialogueResource = preload("res://Dialogue/visitors.dialogue")

const COLOR_UNKNOWN := Color(0.35, 0.32, 0.30)
const COLOR_CLEAR := Color(0.18, 0.42, 0.22)
const COLOR_INFECTED := Color(0.62, 0.16, 0.14)

@onready var _visitor_name: Label = $InfoBox/VisitorName
@onready var _status: Label = $InfoBox/Status
@onready var _dialogue: Control = $InfoBox/DialogueBox
@onready var _stats: Label = $StatsBox/Stats
@onready var _test_button: Button = $InfoBox/Buttons/Test
@onready var _admit_button: Button = $InfoBox/Buttons/Admit
@onready var _deny_button: Button = $InfoBox/Buttons/Deny

var _visitor: Resident
var _busy := false   # True while dialogue plays; buttons are locked


func _ready() -> void:
	_test_button.pressed.connect(_on_test)
	_admit_button.pressed.connect(_on_admit)
	_deny_button.pressed.connect(_on_deny)
	_next_visitor()


func _next_visitor() -> void:
	if GameState.visitors.is_empty():
		GameState.end_stage()
		return
	_visitor = GameState.visitors[0]
	_refresh()
	await _say("greet")


## Plays this visitor's cue, e.g. "v0_greet", with the visitor passed in
## so the dialogue can use {{name}}.
func _say(kind: String) -> void:
	_busy = true
	_refresh()
	await _dialogue.play(VISITOR_DIALOGUE, "v%d_%s" % [_visitor.dialogue_id, kind], [_visitor])
	_busy = false
	_refresh()


func _on_test() -> void:
	if GameState.test_visitor(_visitor):
		await _say("tested")


func _on_admit() -> void:
	if GameState.admit_visitor(_visitor):
		_next_visitor()


func _on_deny() -> void:
	await _say("rejected")
	GameState.turn_away(_visitor)
	_next_visitor()


func _refresh() -> void:
	var waiting := GameState.visitors.size() - 1
	_stats.text = "DAY %d\nFOOD %d\n%d/%d\n%s" % [
		GameState.day, GameState.meals, GameState.residents.size(), Balance.MAX_RESIDENTS,
		"+%d" % waiting if waiting > 0 else ""]

	_visitor_name.text = _visitor.name
	_status.text = _visitor.status_text()
	match _visitor.known_status:
		Resident.Status.POSITIVE: _status.add_theme_color_override("font_color", COLOR_INFECTED)
		Resident.Status.NEGATIVE: _status.add_theme_color_override("font_color", COLOR_CLEAR)
		_: _status.add_theme_color_override("font_color", COLOR_UNKNOWN)

	_test_button.disabled = _busy or not GameState.can_test(_visitor)
	_admit_button.disabled = _busy or GameState.is_farm_full()
	_deny_button.disabled = _busy
	_admit_button.tooltip_text = "The farm is full" if GameState.is_farm_full() else ""
	_test_button.tooltip_text = "Costs %d meal" % Balance.TEST_COST
