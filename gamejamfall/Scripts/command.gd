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
const COL_ICON := 12
const COL_NAME := 34
const COL_STATUS := 40
const COL_DAYS := 36
const COL_TASK := 44
const COL_BUTTON := 12
const COL_GAP := 3

const DRIP_LABEL := preload("res://Scripts/UI/drip_label.gd")

# Juice
const SLIDE_TIME := 0.55          # Panel eases up from below at the start of the day
const SLIDE_DELAY := 0.25         # Lets the screen fade in a little first
const ROW_POP_STAGGER := 0.07     # Rows pop in one after another
const FOOD_TICK_TIME := 0.06      # Seconds per step when the food projection counts up/down

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
var _closing := false     # Set on END DAY: the screen stops updating while it fades out
var _warning_token := 0            # Ignores slow warning lookups that a newer refresh replaced
var _row_of := {}                  # Resident -> their row, for the exile shake
var _bump: Resident = null         # Whose task button bumps on the next rebuild
var _shaking := false              # True while a row shakes before exile (clicks ignored)
var _food_shown := 0               # The projected food the header shows right now (it ticks to the real value)
var _food_tween: Tween
var _food_color := Color(0.14, 0.12, 0.12)


func _ready() -> void:
	_end_day.pressed.connect(_on_end_day)
	_columns.add_theme_constant_override("separation", COL_GAP)
	$Panel/Columns/Name.custom_minimum_size.x = COL_NAME
	$Panel/Columns/Status.custom_minimum_size.x = COL_STATUS
	$Panel/Columns/Days.custom_minimum_size.x = COL_DAYS
	$Panel/Columns/Actions.custom_minimum_size.x = COL_TASK + 2 * (COL_BUTTON + COL_GAP)
	$Panel/Columns/Actions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var icon_space := Control.new()             # Header gap above the head icons
	icon_space.custom_minimum_size.x = COL_ICON
	_columns.add_child(icon_space)
	_columns.move_child(icon_space, 0)
	GameState.residents_changed.connect(_queue_rebuild)
	GameState.meals_changed.connect(_queue_rebuild.unbind(1))
	_food_shown = GameState.projected_meals()
	_rebuild()
	_slide_in()


## Start of the day: the panel eases up from below, then the rows pop in one by one.
func _slide_in() -> void:
	var panel: Control = $Panel
	var rest_y := panel.position.y
	panel.position.y = 135
	for row in _rows.get_children():
		row.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(SLIDE_DELAY)
	tween.tween_property(panel, "position:y", rest_y, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var i := 0
	for row in _rows.get_children():
		var t := create_tween()
		t.tween_interval(SLIDE_DELAY + SLIDE_TIME * 0.6 + i * ROW_POP_STAGGER)
		t.tween_property(row, "modulate:a", 1.0, 0.12)
		i += 1


## Rebuild after the current click finishes, never in the middle of a button's own signal.
func _queue_rebuild() -> void:
	if not _rebuild_queued and not _closing:
		_rebuild_queued = true
		_rebuild.call_deferred()


## END DAY works out the night straight away. Freeze this screen first, so it doesn't
## redraw with tomorrow's numbers while it fades out.
func _on_end_day() -> void:
	_closing = true
	GameState.end_stage()


func _rebuild() -> void:
	_rebuild_queued = false
	if _closing:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row_of.clear()
	for r in GameState.residents:
		var row := _make_row(r)
		_row_of[r] = row
		_rows.add_child(row)
	_bump = null
	_refresh_header()
	_refresh_warning()


func _refresh_header() -> void:
	_day.text = "DAY %d" % GameState.day
	_tick_food(GameState.projected_meals())
	_farm.text = "%d/%d" % [GameState.residents.size(), GameState.max_residents]
	_materials.text = "MATS %d" % GameState.materials   


## The projected food counts up or down to its new value, one step at a time.
## Going negative flashes it red (and it stays red while it's negative).
func _tick_food(target: int) -> void:
	if _food_tween and _food_tween.is_valid():
		_food_tween.kill()
	var went_negative := target < 0 and _food_shown >= 0
	_food_tween = create_tween()
	var steps := absi(target - _food_shown)
	if steps > 0:
		_food_tween.tween_method(_show_food, float(_food_shown), float(target), FOOD_TICK_TIME * steps)
	else:
		_show_food(target)
	if went_negative:
		for k in 3:
			_food_tween.tween_callback(_set_food_color.bind(COLOR_WARNING))
			_food_tween.tween_interval(0.08)
			_food_tween.tween_callback(_set_food_color.bind(Color(0.14, 0.12, 0.12)))
			_food_tween.tween_interval(0.08)
	_food_tween.tween_callback(_set_food_color.bind(COLOR_WARNING if target < 0 else Color(0.14, 0.12, 0.12)))


func _show_food(value: float) -> void:
	_food_shown = roundi(value)
	_food.text = "FOOD %d > %d" % [GameState.meals, _food_shown]


func _set_food_color(c: Color) -> void:
	_food.add_theme_color_override("font_color", c)


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

	var icon := TextureRect.new()
	icon.texture = HeadIcon.for_resident(r)
	icon.custom_minimum_size = Vector2(COL_ICON, 0)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_label := _label(r.name, COL_NAME)
	name_label.clip_text = true
	row.add_child(name_label)

	var status := _label(r.status_text(), COL_STATUS)
	if r.known_status == Resident.Status.POSITIVE:
		status.set_script(DRIP_LABEL)            # "Infected" drips
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
	if r == _bump:
		_bump_up(task)

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


## The task button jumps up a pixel and settles, once the row has been laid out.
func _bump_up(c: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(c):
		return
	var y := c.position.y
	c.position.y = y - 1
	create_tween().tween_property(c, "position:y", y, 0.12)


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
	if _shaking:
		return
	_exile_armed = null
	GameState.test_resident(r)


func _cycle_task(r: Resident, direction: int) -> void:
	if _shaking:
		return
	_exile_armed = null
	_bump = r
	var tasks: Array = GameState.available_tasks(r)   # Lab and Synth only once unlocked
	var i: int = tasks.find(r.task)
	GameState.assign_task(r, tasks[(i + direction + tasks.size()) % tasks.size()])


func _on_task_gui_input(event: InputEvent, r: Resident) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cycle_task(r, -1)


func _on_exile(r: Resident) -> void:
	if _shaking:
		return
	if _exile_armed != r:
		_exile_armed = r
		_queue_rebuild()
		return
	_exile_armed = null
	# Shake the row, then they're gone
	var row: Control = _row_of.get(r)
	if row:
		_shaking = true
		var x := row.position.x
		var tween := create_tween()
		for dx in [2, -2, 2, -1, 1, 0]:
			tween.tween_property(row, "position:x", x + dx, 0.04)
		await tween.finished
		_shaking = false
		if not is_inside_tree() or _closing:
			return
	GameState.exile(r)
