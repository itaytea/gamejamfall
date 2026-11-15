extends Node
## Autoload "Cursor": the pixel-art mouse cursor from Sprites/cursor/.
## Drawn inside the game (not by the operating system), so it's made of exactly
## the same pixels as the rest of the art at any window size, on Mac (Retina),
## Windows and the web. It snaps to the game's pixel grid.
## - default arrow everywhere
## - hover cursor over buttons you can press
## - click cursor while the left mouse button is held

const DEFAULT := "res://Sprites/cursor/cursor_default.png"
const HOVER := "res://Sprites/cursor/cursor_hover.png"
const CLICK := "res://Sprites/cursor/cursor_click.png"
const DEFAULT_HOTSPOT := Vector2(1, 1)   # Tip of the arrow
const HOVER_HOTSPOT := Vector2(4, 4)     # Centre of the target

var _layer := CanvasLayer.new()
var _sprite := TextureRect.new()
var _textures := {}
var _pressed := false
var _inside := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path in [DEFAULT, HOVER, CLICK]:
		_textures[path] = load(path)   # load, not preload: a fresh clone may not have imported them yet
	_layer.layer = 128                 # Above everything, including the fade to black
	add_child(_layer)
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer.add_child(_sprite)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_inside = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_inside = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed


func _process(_delta: float) -> void:
	_sprite.visible = _inside
	var hotspot := DEFAULT_HOTSPOT
	var path := DEFAULT
	if _pressed:
		path = CLICK
		hotspot = HOVER_HOTSPOT
	elif _hovering_button():
		path = HOVER
		hotspot = HOVER_HOTSPOT
	_sprite.texture = _textures[path]
	_sprite.size = _sprite.texture.get_size()
	# Mouse position in game pixels, snapped to the pixel grid
	_sprite.position = (get_viewport().get_mouse_position() - hotspot).floor()


func _hovering_button() -> bool:
	var control := get_viewport().gui_get_hovered_control()
	return control is BaseButton and not control.disabled
