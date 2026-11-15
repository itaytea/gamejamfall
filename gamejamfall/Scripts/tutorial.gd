extends Node
## Autoload "Tutorial": one-time tips. Each tip shows the first time its moment
## comes up (once per game session), in a box over the screen; click through its
## lines. Text is in Dialogue/tutorial.dialogue (cue "tip_<id>").
## Usage from a stage:  await Tutorial.tip("door")
## While a tip is up it blocks clicks to the screen underneath.

const TIPS: DialogueResource = preload("res://Dialogue/tutorial.dialogue")
const BOX_TEXTURE := preload("res://Sprites/base_name_textbox.png")
const DIALOGUE_BOX := preload("res://Scripts/UI/dialogue_box.gd")
const TEXT_COLOR := Color(0.14, 0.12, 0.12)

const ENABLED := true                 ## Turn every tip off (e.g. for quick testing)
const BOX_RECT := Rect2(30, 30, 180, 56)

var _seen := {}
var _busy := false
var _layer := CanvasLayer.new()
var _blocker := ColorRect.new()
var _box: Control
var _panel: NinePatchRect

const SLIDE_TIME := 0.45              # The box eases up from below, like the Command panel
const DIM := 0.35


func _ready() -> void:
	_layer.layer = 9                  # Above the game and the static, below the screen fades
	add_child(_layer)
	_blocker.color = Color(0, 0, 0, DIM)
	_blocker.size = Vector2(240, 135)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_on_blocker_input)
	_layer.add_child(_blocker)

	var panel := NinePatchRect.new()
	_panel = panel
	panel.texture = BOX_TEXTURE
	panel.patch_margin_left = 6
	panel.patch_margin_top = 6
	panel.patch_margin_right = 6
	panel.patch_margin_bottom = 6
	panel.position = BOX_RECT.position
	panel.size = BOX_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blocker.add_child(panel)

	var title := Label.new()
	title.text = "TIP"
	title.position = Vector2(6, 2)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	panel.add_child(title)

	var hint := Label.new()
	hint.text = "click to continue"
	hint.size = Vector2(BOX_RECT.size.x - 12, 8)
	hint.position = Vector2(6, BOX_RECT.size.y - 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(TEXT_COLOR, 0.5))
	panel.add_child(hint)

	var text := RichTextLabel.new()
	text.position = Vector2(7, 16)
	text.size = Vector2(BOX_RECT.size.x - 14, BOX_RECT.size.y - 27)
	text.scroll_active = false
	text.clip_contents = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", 8)
	text.add_theme_color_override("default_color", TEXT_COLOR)
	text.add_theme_constant_override("line_separation", 1)
	panel.add_child(text)

	_box = Control.new()
	_box.set_script(DIALOGUE_BOX)
	_box.text_label = text
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_box)
	_layer.hide()


## Shows the tip once per session. Returns right away if it was already seen.
func tip(id: String) -> void:
	if not ENABLED or _seen.has(id) or _busy:
		return
	_seen[id] = true
	_busy = true
	_box.text_label.text = ""
	# Slide in from below while the screen dims
	_panel.position.y = 135
	_blocker.color.a = 0.0
	_layer.show()
	var tween := create_tween().set_parallel()
	tween.tween_property(_blocker, "color:a", DIM, SLIDE_TIME * 0.6)
	tween.tween_property(_panel, "position:y", BOX_RECT.position.y, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	await _box.play(TIPS, "tip_" + id)
	# Drop back out
	tween = create_tween().set_parallel()
	tween.tween_property(_blocker, "color:a", 0.0, 0.2)
	tween.tween_property(_panel, "position:y", 135.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	_layer.hide()
	_busy = false


func has_seen(id: String) -> bool:
	return _seen.has(id)


func _on_blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_box.advance()
		get_viewport().set_input_as_handled()
