@tool
class_name WaveTextEffect
extends RichTextEffect
## [bob]text[/bob]: a gentle wave runs through the letters. Each letter is either
## at rest or lifted by exactly one pixel (`step`, in game pixels),
## so the text stays pixel-perfect.
## Optional: [bob speed=1.5 freq=0.3 step=1.0 lift=0.5]

var bbcode := "bob"


func _process_custom_fx(fx: CharFXTransform) -> bool:
	var speed: float = fx.env.get("speed", 1.5)    # How fast the wave moves
	var freq: float = fx.env.get("freq", 0.3)      # How tight the wave is (per letter)
	var step: float = fx.env.get("step", 1.0)      # The one pixel a letter lifts (in game pixels)
	var lift: float = fx.env.get("lift", 0.5)      # Higher = fewer letters lifted at once (-1 to 1)
	var wave := sin(fx.elapsed_time * speed - fx.relative_index * freq)
	fx.offset.y = -step if wave > lift else 0.0
	return true
