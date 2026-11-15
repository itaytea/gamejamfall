extends Node
## Autoload "Sfx": sound effects (files in Music/SFX/).
## - Sfx.play("name") plays a sound. Several can overlap.
## - Every button in the game clicks (clicklowerpitch) on press, automatically.
##   Give a button the meta "no_click" to skip that (e.g. test buttons, which
##   play their result instead).
## - Sfx.play_test_result(r) plays testpos / testneg / testinc for a fresh test.

const SOUNDS := {
	"click": preload("res://Music/SFX/clicklowerpitch.wav"),
	"command": preload("res://Music/SFX/command.wav"),
	"death": preload("res://Music/SFX/death.wav"),
	"testpos": preload("res://Music/SFX/testpos.wav"),
	"testneg": preload("res://Music/SFX/testneg.wav"),
	"testinc": preload("res://Music/SFX/testinc.wav"),
	"voice_low": preload("res://Music/SFX/lowspeak.mp3"),
	"voice_medium": preload("res://Music/SFX/mediumspeak.mp3"),
	"voice_high": preload("res://Music/SFX/highspeak.mp3"),
}
## A resident's Resident.voice (0, 1, 2) -> their blip sound
const VOICES_BY_TONE := ["voice_low", "voice_medium", "voice_high"]
const VOLUME_DB := {           # Per-sound volume; anything missing is 0 dB
	"click": -4.0,
}
const CLICK_PITCH_JITTER := 0.04   # Clicks vary a little so repeats don't sound robotic
const VOICES := 8                  # How many sounds can play at once

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


func play(sound: String, pitch := 1.0) -> void:
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = SOUNDS[sound]
	p.volume_db = VOLUME_DB.get(sound, 0.0)
	p.pitch_scale = pitch
	p.play()


## After a test: the sound for the result it just gave.
func play_test_result(r: Resident) -> void:
	match r.known_status:
		Resident.Status.POSITIVE: play("testpos")
		Resident.Status.NEGATIVE: play("testneg")
		Resident.Status.INCONCLUSIVE: play("testinc")


func click() -> void:
	play("click", 1.0 + randf_range(-CLICK_PITCH_JITTER, CLICK_PITCH_JITTER))


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(_on_button_pressed.bind(node))


func _on_button_pressed(button: BaseButton) -> void:
	if not button.has_meta("no_click"):
		click()
