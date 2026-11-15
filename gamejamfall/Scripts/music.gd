extends Node
## Autoload "Music": the layered soundtrack. All seven stems play together in
## sync (one AudioStreamSynchronized) and loop forever; layers fade in and out
## with the game. Stems are 96 bars at 100 bpm, so they always line up.
##
## Rules (checked "when morning rises", i.e. the first morning screen of each day,
## and again when night falls):
## - bass pad: always, even after losing
## - high pad: always, until you lose (it's the last layer to go)
## - drums + bass loop: mornings only, and only if 1 or fewer people are infected
## - guitar: mornings only, if there's more food than mouths (residents + you)
## - glitter: mornings only, if fewer than half the farm is infected
## - swells: day and night; after night SWELLS_SAFE_NIGHTS they stop if half or
##   more of the farm is infected or there's less food than mouths
## - winning brings every layer in

const STEMS := [
	["bass_pad", "res://Music/ogg/bass_pad.ogg"],
	["high_pad", "res://Music/ogg/high_pad.ogg"],
	["swells", "res://Music/ogg/swells.ogg"],
	["drums", "res://Music/ogg/drums.ogg"],
	["bass_loop", "res://Music/ogg/bass_loop.ogg"],
	["guitar", "res://Music/ogg/guitar.ogg"],
	["glitter", "res://Music/ogg/glitter.ogg"],
]
const MUSIC_VOLUME_DB := -6.0          # Overall music volume
const FADE_SECONDS := 4.8              # Two bars at 100 bpm
const SWELLS_SAFE_NIGHTS := 10         # Swells can't drop out before this night
## false: "infected" means people the player KNOWS are infected (shown as Infected).
## true: it counts hidden infections too, so the music would hint at them.
const USE_HIDDEN_INFECTIONS := false

const SILENT_DB := -60.0

var _player := AudioStreamPlayer.new()
var _sync := AudioStreamSynchronized.new()
var _index := {}          # stem name -> index in the synchronized stream
var _level := {}          # stem name -> current loudness, 0..1
var _tweens := {}
var _night := true        # So the very first screen of a run counts as morning rising


func _ready() -> void:
	_sync.stream_count = STEMS.size()
	for i in STEMS.size():
		var stream: AudioStream = load(STEMS[i][1])
		stream.loop = true
		_sync.set_sync_stream(i, stream)
		_sync.set_sync_stream_volume(i, SILENT_DB)
		_index[STEMS[i][0]] = i
		_level[STEMS[i][0]] = 0.0
	_player.stream = _sync
	_player.volume_db = MUSIC_VOLUME_DB
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.play()
	GameState.stage_changed.connect(_on_stage_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)


func _on_stage_changed(stage: int) -> void:
	if stage == GameState.Stage.CONSEQUENCES:
		_nightfall()
	elif _night:              # Admission or Command, first one of the day
		_morning_rises()


func _morning_rises() -> void:
	_night = false
	var infected := _infected_count()
	_fade("bass_pad", true)
	_fade("high_pad", true)
	_fade("drums", infected <= 1)
	_fade("bass_loop", infected <= 1)
	_fade("guitar", GameState.meals > _mouths())
	_fade("glitter", _infected_ratio() < 0.5)
	_fade("swells", _swells_on())


func _nightfall() -> void:
	_night = true
	for stem in ["drums", "bass_loop", "guitar", "glitter"]:
		_fade(stem, false)
	_fade("bass_pad", true)
	_fade("high_pad", true)
	_fade("swells", _swells_on())


func _on_game_over(_reason: String, _days: int) -> void:
	_night = true
	for stem in ["swells", "drums", "bass_loop", "guitar", "glitter"]:
		_fade(stem, false)
	_fade("high_pad", false, FADE_SECONDS)    # Last to go: starts fading after the others
	_fade("bass_pad", true)


func _on_game_won(_day: int) -> void:
	_night = true
	for stem in _index:
		_fade(stem, true)


# ---------------------------------------------------------------- Farm checks

func _farm() -> Array:
	return GameState.present_residents()


func _infected_count() -> int:
	if USE_HIDDEN_INFECTIONS:
		return _farm().filter(func(r): return r.is_infected).size()
	return _farm().filter(func(r): return r.known_status == Resident.Status.POSITIVE).size()


func _infected_ratio() -> float:
	var people := _farm().size()
	return 0.0 if people == 0 else float(_infected_count()) / people


func _mouths() -> int:
	return _farm().size() + 1     # Residents at home, plus you


func _swells_on() -> bool:
	if GameState.day <= SWELLS_SAFE_NIGHTS:
		return true
	return not (_infected_ratio() >= 0.5 or GameState.meals < _mouths())


# ---------------------------------------------------------------- Fading

func _fade(stem: String, on: bool, delay := 0.0) -> void:
	var target := 1.0 if on else 0.0
	if _tweens.has(stem) and _tweens[stem].is_valid():
		_tweens[stem].kill()
	if is_equal_approx(_level[stem], target):
		return
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(_set_level.bind(stem), _level[stem], target, FADE_SECONDS)
	_tweens[stem] = tween


func _set_level(value: float, stem: String) -> void:
	_level[stem] = value
	var db := SILENT_DB if value <= 0.001 else maxf(linear_to_db(value), SILENT_DB)
	_sync.set_sync_stream_volume(_index[stem], db)


## For debugging / the F1 overlay: which layers are on right now.
func layer_levels() -> Dictionary:
	return _level.duplicate()
