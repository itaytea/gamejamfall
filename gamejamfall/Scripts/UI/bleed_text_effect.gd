@tool
class_name BleedTextEffect
extends RichTextEffect
## [bleed]infected[/bleed]: letters sag one pixel at a time and darken a little,
## like they're dripping. Adds to any other offset (so it works inside [bob]).
## dialogue_box.gd wraps every "infected" in this, coloured red.

var bbcode := "bleed"

const PERIOD := 1.6        # Seconds between sags for each letter
const SAG_TIME := 0.35     # How long a letter hangs down


func _process_custom_fx(fx: CharFXTransform) -> bool:
	# Each letter gets its own rhythm, so they drip one by one
	var phase := fmod(fx.relative_index * 0.61, 1.0) * PERIOD
	var t := fmod(fx.elapsed_time + phase, PERIOD)
	if t < SAG_TIME:
		fx.offset.y += 1.0
		fx.color = fx.color.darkened(0.25)
	return true
