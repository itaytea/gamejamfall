class_name ResidentRows
extends RefCounted
## Shared bits for the little resident lists (the night's ration picker and the
## folder roster at the door): status colours and a row of fixed-width columns.

const COLOR_TEXT := Color(0.14, 0.12, 0.12)
const COLOR_UNKNOWN := Color(0.35, 0.32, 0.30)
const COLOR_CLEAR := Color(0.18, 0.42, 0.22)
const COLOR_INFECTED := Color(0.62, 0.16, 0.14)
const COLOR_INCONCLUSIVE := Color(0.62, 0.45, 0.10)

const ROW_HEIGHT := 11
const FONT_SIZE := 8


static func status_color(r: Resident) -> Color:
	match r.known_status:
		Resident.Status.POSITIVE: return COLOR_INFECTED
		Resident.Status.NEGATIVE: return COLOR_CLEAR
		Resident.Status.INCONCLUSIVE: return COLOR_INCONCLUSIVE
	return COLOR_UNKNOWN


## Labels side by side, each `widths[i]` pixels wide. Fills its parent and
## ignores the mouse, so it can sit inside a Button or a Panel.
static func columns(texts: Array, widths: Array) -> HBoxContainer:
	var cols := HBoxContainer.new()
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols.offset_left = 4
	cols.add_theme_constant_override("separation", 0)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in texts.size():
		var l := Label.new()
		l.text = texts[i]
		l.custom_minimum_size.x = widths[i]
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		l.add_theme_color_override("font_color", COLOR_TEXT)
		cols.add_child(l)
	return cols


## Colours a row made by columns(): the status column (index 1) gets its
## infection colour, the rest plain text. Pass `override` to colour it all.
static func color_row(cols: Control, r: Resident, override: Variant = null) -> void:
	var labels := cols.get_children()
	for i in labels.size():
		var c: Color = override if override != null else (status_color(r) if i == 1 else COLOR_TEXT)
		labels[i].add_theme_color_override("font_color", c)
