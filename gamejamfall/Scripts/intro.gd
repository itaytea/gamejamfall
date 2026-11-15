extends Control
## Opening cutscene: a background per part, white text in a black box along the
## bottom sixth of the screen. Fades through black between parts, then starts
## the game (Main.tscn, which fades in from black). Esc skips the whole intro.
## Text lives in Dialogue/intro.dialogue (cues intro_1, intro_2, ...).

const INTRO_DIALOGUE: DialogueResource = preload("res://Dialogue/intro.dialogue")
const FADE_TIME := 0.6
const NEXT_SCENE := "res://Scenes/Main.tscn"

## One entry per part, in order. null = plain black background.
const PARTS: Array = [
	null,                                                 # intro_1: black
	preload("res://Sprites/intro/tv.png"),                # intro_2: TV broadcast
	null,                                                 # intro_3: black
	preload("res://Sprites/intro/fence.png"),             # intro_4: fence
	preload("res://Sprites/intro/box.png"),               # intro_5: box of test strips
	preload("res://Sprites/background_command.png"),      # intro_6: PLACEHOLDER, swap for the real art
]

## Static (picture and sound) per part, 0 = none. intro_3 is the broadcast turning to static.
const PART_STATIC: Array = [0.0, 0.0, 0.45, 0.0, 0.0, 0.0]
const STATIC_SOUND_DB := -4.0          # Static sound volume at full part strength

@onready var _background: TextureRect = $Background
@onready var _static: ColorRect = $Static
var _static_sound := AudioStreamPlayer.new()
@onready var _dialogue: Control = $TextBox/DialogueBox
@onready var _fade: ColorRect = $Fade

var _leaving := false


func _ready() -> void:
	_fade.color.a = 1.0
	Music.play_intro()
	var sound: AudioStreamMP3 = preload("res://Music/SFX/static.mp3").duplicate()
	sound.loop = true
	_static_sound.stream = sound
	add_child(_static_sound)
	for i in PARTS.size():
		if _leaving: return
		_background.texture = PARTS[i]
		_dialogue.text_label.text = ""
		_set_static(PART_STATIC[i])
		await _tween_fade(0.0)
		if _leaving: return
		await _dialogue.play(INTRO_DIALOGUE, "intro_%d" % (i + 1))
		if _leaving: return
		await _tween_fade(1.0)
		_set_static(0.0)
	_start_game()


## Static on (screen is black when this is called, so it fades in with the part).
## The sound follows the fade: Fade alpha 1 = silent.
func _set_static(strength: float) -> void:
	(_static.material as ShaderMaterial).set_shader_parameter("intensity", strength)
	_static.visible = strength > 0.0
	if strength > 0.0 and not _static_sound.playing:
		_static_sound.play()
	elif strength <= 0.0:
		_static_sound.stop()


func _process(_delta: float) -> void:
	if _static_sound.playing:
		var level := 1.0 - _fade.color.a                 # Fades in and out with the screen
		_static_sound.volume_db = STATIC_SOUND_DB + linear_to_db(maxf(level, 0.001))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _leaving:
		get_viewport().set_input_as_handled()
		_dialogue.is_playing = false
		await _tween_fade(1.0)
		_start_game()


func _start_game() -> void:
	if _leaving: return
	_leaving = true
	get_tree().change_scene_to_file(NEXT_SCENE)


func _tween_fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished
