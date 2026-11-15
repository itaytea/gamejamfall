extends Control
## Plays Dialogue Manager cues line by line into whatever labels you point it at.
## Text scrolls in letter by letter. Click anywhere (or press Enter/Space):
##   - while text is scrolling: show the whole line at once
##   - once the line is fully shown: go to the next line
## Usage:
##     await $DialogueBox.play(resource, "cue_name", [some_object])
## Reusable: the night report can use this same script with its own labels.
## Sound: text scrolls with a blip every few letters (`voice`: a sound name in Sfx,
## "click" unless a speaker sets their own), with a slight pitch wobble.
## Moving on to the next line, or closing the box, clicks.

signal _advanced

@export var text_label: RichTextLabel
@export var name_label: Label            ## Optional: leave empty if the speaker's name is shown elsewhere
@export var hide_when_idle := false      ## Hide this node between conversations
@export var characters_per_second := 40.0
@export var wave := true                 ## Letters gently bob up and down (WaveTextEffect)
@export var voice := "click"             ## Blip sound while typing (a name in Sfx.SOUNDS)

const BLIP_EVERY := 2                    # A blip every this many letters
const BLIP_PITCH_JITTER := 0.08
const BLIP_VOLUME_DB := {"click": -14.0}  # Per-sound blip volume (default VOICE_VOLUME_DB)
const VOICE_VOLUME_DB := 2.0             # Visitors' speech blips

## Every "infected" in a line turns red and drips (BleedTextEffect), game-wide.
const INFECTED_COLOR := Color(0.62, 0.16, 0.14)
static var _infected_regex := RegEx.create_from_string("(?i)\\binfected\\b")

var is_playing := false
var is_typing := false
var _shown := 0.0   # Characters revealed so far (fractional, so speed is frame-rate independent)
var _blip := AudioStreamPlayer.new()   # One player, restarted per blip, so blips never pile up
var _letters_since_blip := 0


func _ready() -> void:
	text_label.bbcode_enabled = true
	text_label.install_effect(WaveTextEffect.new())
	text_label.install_effect(BleedTextEffect.new())
	add_child(_blip)
	if hide_when_idle:
		hide()


func play(resource: DialogueResource, cue: String, extra_game_states: Array = []) -> void:
	is_playing = true
	show()
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, cue, extra_game_states)
	while line != null:
		if name_label:
			name_label.text = line.character
		_start_typing(line.text)
		await _advanced
		line = await DialogueManager.get_next_dialogue_line(resource, line.next_id, extra_game_states)
	is_playing = false
	if hide_when_idle:
		hide()


## Skip the scrolling if it's still going, otherwise move to the next line.
## Called by clicks and Enter/Space; other scripts can call it too.
func advance() -> void:
	if not is_playing:
		return
	if is_typing:
		_finish_typing()
	else:
		Sfx.click()                       # Next line, or closing the box
		_advanced.emit()


func _start_typing(text: String) -> void:
	text = text.replace("[", "[lb]")       # Show any [ in the line as-is, not as a tag
	text = _infected_regex.sub(text, "[color=#%s][bleed]$0[/bleed][/color]" % INFECTED_COLOR.to_html(false), true)
	text_label.text = "[bob]%s[/bob]" % text if wave else text
	text_label.visible_characters = 0
	_shown = 0.0
	_letters_since_blip = BLIP_EVERY      # First letter blips straight away
	is_typing = true


func _finish_typing() -> void:
	text_label.visible_characters = -1   # -1 = show everything
	is_typing = false


func _process(delta: float) -> void:
	if not is_typing:
		return
	_shown += characters_per_second * delta
	var before := text_label.visible_characters
	text_label.visible_characters = int(_shown)
	for i in range(before, text_label.visible_characters):
		_on_letter(i)
	if text_label.visible_characters >= text_label.get_total_character_count():
		_finish_typing()


## A letter appeared: blip every BLIP_EVERY letters (spaces don't count).
func _on_letter(index: int) -> void:
	var c := text_label.get_parsed_text().substr(index, 1)
	if c.strip_edges() == "":
		return
	_letters_since_blip += 1
	if _letters_since_blip < BLIP_EVERY:
		return
	_letters_since_blip = 0
	_blip.stream = Sfx.SOUNDS.get(voice, Sfx.SOUNDS["click"])
	_blip.volume_db = BLIP_VOLUME_DB.get(voice, VOICE_VOLUME_DB)
	_blip.pitch_scale = 1.0 + randf_range(-BLIP_PITCH_JITTER, BLIP_PITCH_JITTER)
	_blip.play()


## Any click that no button took advances the dialogue.
func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
