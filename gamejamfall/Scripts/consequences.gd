extends Control
## Night report: plays each of tonight's events (GameState.events) as dialogue,
## one after another, then moves on (next day, or game over).
## Each event's "type" is a cue in Dialogue/report.dialogue.

const REPORT_DIALOGUE: DialogueResource = preload("res://Dialogue/report.dialogue")

@onready var _title: Label = $Box/Title
@onready var _dialogue: Control = $Box/DialogueBox


func _ready() -> void:
	_title.text = "NIGHT %d" % GameState.day
	_play_report()


func _play_report() -> void:
	for event in GameState.events:
		await _dialogue.play(REPORT_DIALOGUE, event.type, [event])
	GameState.end_stage()
