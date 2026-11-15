extends Control
## Admission stage: visitors come to the door one at a time.
## Test (costs a meal), Admit (free, if there's room) or Deny.
## Layout follows Sprites/ADMIT SCREEN REFERENCE.png.

const VISITOR_DIALOGUE: DialogueResource = preload("res://Dialogue/visitors.dialogue")

const COLOR_UNKNOWN := Color(0.35, 0.32, 0.30)
const COLOR_CLEAR := Color(0.18, 0.42, 0.22)
const COLOR_INFECTED := Color(0.62, 0.16, 0.14)
const COLOR_INCONCLUSIVE := Color(0.62, 0.45, 0.10)

@onready var _portrait: Control = $Visitor
@onready var _visitor_name: Label = $InfoBox/VisitorName
@onready var _status: Label = $InfoBox/Status
@onready var _dialogue: Control = $InfoBox/DialogueBox
@onready var _day: Label = $StatsBox/Day
@onready var _stats: Label = $StatsBox/Stats
@onready var _test_button: Button = $InfoBox/Buttons/Test
@onready var _admit_button: Button = $InfoBox/Buttons/Admit
@onready var _deny_button: Button = $InfoBox/Buttons/Deny
@onready var _folder: TextureButton = $Folder
@onready var _roster: Control = $Roster
@onready var _roster_title: Label = $Roster/Title
@onready var _roster_list: VBoxContainer = $Roster/List

# Folder roster: NAME | INFECTED? | WHERE (see ResidentRows)
const ROSTER_COLS := [52, 50, 60]

var _visitor: Resident
var _busy := false   # True while dialogue plays; buttons are locked


func _ready() -> void:
	_test_button.pressed.connect(_on_test)
	_admit_button.pressed.connect(_on_admit)
	_deny_button.pressed.connect(_on_deny)
	_folder.mouse_entered.connect(_show_roster)
	_folder.mouse_exited.connect(_hide_roster)
	_next_visitor(true)


## Shows the next visitor at the door. The first one arrives with the stage's
## own fade; later ones fade through black (Main.fade_through) so the swap
## happens off-screen. With nobody left, the stage ends (Main fades that too).
func _next_visitor(first := false) -> void:
	if GameState.visitors.is_empty():
		GameState.end_stage()
		return
	var main := get_tree().current_scene
	if first or not main.has_method("fade_through"):
		_show_visitor()
	else:
		_busy = true                                    # Lock buttons through the fade
		_refresh()
		await main.fade_through(_show_visitor)
	await _say("greet")


func _show_visitor() -> void:
	_visitor = GameState.visitors[0]
	_dialogue.text_label.text = ""                      # Drop the last visitor's line
	_refresh()


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
	var waiting: int = GameState.visitors.size() - 1
	_day.text = "Day %d" % GameState.day
	_stats.text = "Meals: %d\nMats: %d\nBeds: %d/%d%s" % [
		GameState.meals, GameState.materials, GameState.residents.size(), GameState.max_residents,
		"\n+%d waiting" % waiting if waiting > 0 else ""]   # Visitors still in line after this one

	_portrait.show_resident(_visitor)
	_visitor_name.text = _visitor.name
	_status.text = _visitor.status_text()
	match _visitor.known_status:
		Resident.Status.POSITIVE: _status.add_theme_color_override("font_color", COLOR_INFECTED)
		Resident.Status.NEGATIVE: _status.add_theme_color_override("font_color", COLOR_CLEAR)
		Resident.Status.INCONCLUSIVE: _status.add_theme_color_override("font_color", COLOR_INCONCLUSIVE)
		_: _status.add_theme_color_override("font_color", COLOR_UNKNOWN)

	_test_button.disabled = _busy or not GameState.can_test(_visitor)
	_admit_button.disabled = _busy or GameState.is_farm_full()
	_deny_button.disabled = _busy


# -- Folder roster: hover the folder to see who's on the farm --

func _show_roster() -> void:
	for child in _roster_list.get_children():
		_roster_list.remove_child(child)
		child.queue_free()
	_roster_title.text = "RESIDENTS  %d/%d" % [GameState.residents.size(), GameState.max_residents]
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.set_border_width_all(1)
	border.border_color = ResidentRows.COLOR_TEXT
	for r: Resident in GameState.residents:
		var row := Panel.new()
		row.custom_minimum_size.y = ResidentRows.ROW_HEIGHT
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", border)
		var cols := ResidentRows.columns([r.name, r.status_text(), _whereabouts(r)], ROSTER_COLS)
		ResidentRows.color_row(cols, r)
		row.add_child(cols)
		_roster_list.add_child(row)
	if GameState.residents.is_empty():
		var l := Label.new()
		l.text = "No one lives here."
		l.add_theme_font_size_override("font_size", ResidentRows.FONT_SIZE)
		l.add_theme_color_override("font_color", ResidentRows.COLOR_TEXT)
		_roster_list.add_child(l)
	# Grow the window to fit the list
	var rows := maxi(GameState.residents.size(), 1)
	_roster.size.y = 18 + rows * (ResidentRows.ROW_HEIGHT + 2) + 6
	_folder.position.y = 83                    # Folder lifts a pixel while open
	_roster.show()


func _hide_roster() -> void:
	_folder.position.y = 84
	_roster.hide()


## Where a resident is right now: out on a trip (and how many nights until
## they're due back), synthesizing the cure, or home.
func _whereabouts(r: Resident) -> String:
	if r.is_away:
		var place := "At the lab" if r.task == Resident.Task.LAB else "On the road"
		return "%s (%dd)" % [place, r.forage_days_left]
	if r.task == Resident.Task.SYNTHESIZER:
		return "Synthesizing"
	return "Home"
