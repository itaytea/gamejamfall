extends Node
## Autoload "Cursor": the pixel-art mouse cursor from Sprites/cursor/.
## - default arrow everywhere, the hover cursor over buttons, the click cursor
##   while the left mouse button is held
## - scaled up with the game (whole-number steps, like the art) so it stays the
##   same size relative to everything else, at any window size

# Loaded at startup (not preloaded) so a fresh clone doesn't fail before Godot imports the art
const DEFAULT := "res://Sprites/cursor/cursor_default.png"
const HOVER := "res://Sprites/cursor/cursor_hover.png"
const CLICK := "res://Sprites/cursor/cursor_click.png"
const DEFAULT_HOTSPOT := Vector2(1, 1)   # Tip of the arrow
const HOVER_HOTSPOT := Vector2(4, 4)     # Centre of the target
const BASE_SIZE := Vector2(240, 135)     # Game resolution
const MAX_SCALE := 16                    # Browsers refuse cursors bigger than 128x128

var _scale := 0
var _pressed := false
var _scaled := {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_refresh)
	_refresh()


## Every button shows the hover cursor.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed
		_apply()


func _refresh() -> void:
	var window := Vector2(DisplayServer.window_get_size())
	var s := clampi(int(floor(minf(window.x / BASE_SIZE.x, window.y / BASE_SIZE.y))), 1, MAX_SCALE)
	if s != _scale:
		_scale = s
		_scaled.clear()
		for path in [DEFAULT, HOVER, CLICK]:
			var tex: Texture2D = load(path)
			var img: Image = tex.get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
			_scaled[path] = ImageTexture.create_from_image(img)
	_apply()


func _apply() -> void:
	var arrow: Texture2D = _scaled[CLICK] if _pressed else _scaled[DEFAULT]
	var hand: Texture2D = _scaled[CLICK] if _pressed else _scaled[HOVER]
	Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, (HOVER_HOTSPOT if _pressed else DEFAULT_HOTSPOT) * _scale)
	Input.set_custom_mouse_cursor(hand, Input.CURSOR_POINTING_HAND, HOVER_HOTSPOT * _scale)
