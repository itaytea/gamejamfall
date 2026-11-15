extends Control
## Command stage: see every resident, give them a task, exile people, end the day.
## - Click a task to cycle Idle > Guard > Garden > Forage > Research (> Lab > Synth once unlocked).
##   Right-click goes backwards.
## - Foragers leave when you press End Day, so you can change your mind until then.
## - T tests a resident (costs a meal). Anyone but known-infected can be retested.
## - Exile costs a meal: click X once to arm it (shows ?), click again to confirm.
## Rows are built in code; their look comes from the Theme on this scene's root.

const COLOR_UNKNOWN := Color(0.35, 0.32, 0.30)
const COLOR_CLEAR := Color(0.18, 0.42, 0.22)
const COLOR_INFECTED := Color(0.62, 0.16, 0.14)
const COLOR_INCONCLUSIVE := Color(0.62, 0.45, 0.10)
const COLOR_WARNING := Color(0.62, 0.16, 0.14)
const WARNINGS: DialogueResource = preload("res://Dialogue/warnings.dialogue")

# Column widths, shared by the header row and every resident row so they line up
const COL_NAME := 46
const COL_STATUS := 50
const COL_DAYS := 34
const COL_TASK := 44
const COL_BUTTON := 12
const COL_GAP := 3

const TASK_NAMES := {
	Resident.Task.IDLE: "Idle",
	Resident.Task.GUARD: "Guard",
	Resident.Task.GARDENER: "Garden",
	Resident.Task.FORAGER: "Forage",
	Resident.Task.RESEARCHER: "Research",
	Resident.Task.LAB: "Lab",
	Resident.Task.SYNTHESIZER: "Synth",
	Resident.Task.BUILDER: "Build Bed",
}

@onready var _day: Label = $Panel/Header/Day
@onready var _food: Label = $Panel/Header/Food
@onready var _materials: Label = $Panel/Header/Materials
@onready var _farm: Label = $Panel/Header/Farm
@onready var _rows: VBoxContainer = $Panel/Rows
@onready var _columns: HBoxContainer = $Panel/Columns
@onready var _warning: Label = $Panel/Warning
@onready var _end_day: Button = $Panel/EndDay

var _exile_armed: Resident = null   # Resident whose X was clicked once
var _rebuild_queued := false
var _warning_token := 0            # Ignores slow warning lookups that a newer refresh replaced


func _ready() -> void:
	_end_day.pressed.connect(GameState.end_stage)
	_columns.add_theme_constant_override("separation", COL_GAP)
	$Panel/Columns/Name.custom_minimum_size.x = COL_NAME
	$Panel/Columns/Status.custom_minimum_size.x = COL_STATUS
	$Panel/Columns/Days.custom_minimum_size.x = COL_DAYS
	$Panel/Columns/Actions.custom_minimum_size.x = COL_TASK + 2 * (COL_BUTTON + COL_GAP)
	GameState.residents_changed.connect(_queue_rebuild)
	GameState.meals_changed.connect(_queue_rebuild.unbind(1))
	_rebuild()


## Rebuild after the current click finishes, never in the middle of a button's own signal.
func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for r in GameState.residents:
		_rows.add_child(_make_row(r))
	_refresh_header()
	_refresh_warning()


func _refresh_header() -> void:
	_day.text = "DAY %d" % GameState.day
	_food.text = "FOOD %d > %d" % [GameState.meals, GameState.projected_meals()]
	_farm.text = "%d/%d" % [GameState.residents.size(), GameState.max_residents]
	_materials.text = "MATS %d" % GameState.materials   


## Warning text lives in Dialogue/warnings.dialogue so it can be edited without code.
func _refresh_warning() -> void:
	_warning_token += 1
	var token := _warning_token
	var gardeners: int = GameState.residents.filter(
		func(r): return r.is_present() and r.task == Resident.Task.GARDENER).size()
	var cues: Array[String] = []
	if GameState.projected_meals() < 0:
		cues.append("not_enough_food")
	if not GameState.has_guard():
		cues.append("no_guard")
	if gardeners > Balance.GARDEN_PLOTS:
		cues.append("too_many_gardeners")
	var values := {
		"food": GameState.meals,
		"projected": GameState.projected_meals(),
		"gardeners": gardeners,
		"plots": Balance.GARDEN_PLOTS,
	}
	var lines: Array[String] = []
	for cue in cues.slice(0, 2):
		var line: DialogueLine = await DialogueManager.get_next_dialogue_line(WARNINGS, cue, [values])
		if token != _warning_token or not is_inside_tree():
			return
		if line:
			lines.append(line.text)
	_warning.text = "\n".join(PackedStringArray(lines))


func _make_row(r: Resident) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", COL_GAP)

	var name_label := _label(r.name, COL_NAME)
	name_label.clip_text = true
	row.add_child(name_label)

	var status := _label(r.status_text(), COL_STATUS)
	status.add_theme_color_override("font_color", _status_color(r))
	row.add_child(status)

	row.add_child(_label(str(r.days_on_farm), COL_DAYS))

	# Actions: task toggle, then test, then exile
	var task := Button.new()
	task.custom_minimum_size = Vector2(COL_TASK, 0)
	if r.is_away:
		task.text = ("Lab %d" if r.task == Resident.Task.LAB else "Away %d") % r.forage_days_left
		task.disabled = true
	else:
		task.text = TASK_NAMES[r.task]
		task.pressed.connect(_cycle_task.bind(r, 1))
		task.gui_input.connect(_on_task_gui_input.bind(r))
	row.add_child(task)

	var test := Button.new()
	test.custom_minimum_size = Vector2(COL_BUTTON, 0)
	test.text = "T"
	test.disabled = not GameState.can_test_resident(r)
	test.pressed.connect(_on_test.bind(r))
	row.add_child(test)

	var exile := Button.new()
	exile.custom_minimum_size = Vector2(COL_BUTTON, 0)
	exile.text = "?" if _exile_armed == r else "X"
	exile.disabled = not GameState.can_exile(r)
	exile.pressed.connect(_on_exile.bind(r))
	row.add_child(exile)
	return row


func _label(text: String, width: int) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _status_color(r: Resident) -> Color:
	match r.known_status:
		Resident.Status.POSITIVE: return COLOR_INFECTED
		Resident.Status.NEGATIVE: return COLOR_CLEAR
		Resident.Status.INCONCLUSIVE: return COLOR_INCONCLUSIVE
	return COLOR_UNKNOWN


func _on_test(r: Resident) -> void:
	_exile_armed = null
	GameState.test_resident(r)


func _cycle_task(r: Resident, direction: int) -> void:
	_exile_armed = null
	var tasks: Array = GameState.available_tasks(r)   # Lab and Synth only once unlocked
	var i: int = tasks.find(r.task)
	GameState.assign_task(r, tasks[(i + direction + tasks.size()) % tasks.size()])


func _on_task_gui_input(event: InputEvent, r: Resident) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cycle_task(r, -1)


func _on_exile(r: Resident) -> void:
	if _exile_armed != r:
		_exile_armed = r
		_queue_rebuild()
		return
	_exile_armed = null
	GameState.exile(r)
