extends Control
## Cached 2D resource readout. It follows replicated class state, never predicts costs.
const RESOURCE_BLUE := Color("327ce6")
const COLORS := {"Ember": RESOURCE_BLUE, "Vanguard": RESOURCE_BLUE, "Fulcrum": RESOURCE_BLUE, "Luminary": RESOURCE_BLUE, "Outlaw": RESOURCE_BLUE, "Null": Color("8b9dab")}
var champion := ""
var amount := 0.0
var maximum := 100.0
var readout: Label
var thresholds: Array = []
var cache := ""
var track_style := box(Color("182334"))
var fill_style := box(Color.WHITE)
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	readout = Label.new()
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	readout.add_theme_font_size_override("font_size", 12)
	readout.add_theme_color_override("font_color", Color.WHITE)
	readout.add_theme_color_override("font_outline_color", Color("090d13"))
	readout.add_theme_constant_override("outline_size", 4)
	add_child(readout)
	readout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	readout.hide()
func sync(actor, _is_personal: bool) -> void:
	champion = actor.champion
	var state: Dictionary = actor.identity
	fill_style.bg_color = COLORS.get(champion, Color.WHITE)
	maximum = 120.0 if champion == "Null" else 100.0
	amount = float(state.get({"Ember":"heat", "Vanguard":"resolve", "Fulcrum":"meditation", "Null":"essence"}.get(champion, ""), 0))
	thresholds = {"Ember":[20, 40], "Vanguard":[40], "Fulcrum":[50, 75], "Null":[100]}.get(champion, [])
	if champion == "Luminary": amount = state.stars.size()
	if champion == "Outlaw": amount = state.get("defense_detonation", 0)
	if readout != null:
		readout.visible = champion == "Null"
		if readout.visible: readout.text = "Essence %d / 120" % roundi(amount)
	var key := "%s:%s:%s" % [champion, amount, size]
	if key != cache:
		cache = key
		queue_redraw()
func _draw() -> void:
	if champion.is_empty(): return
	var tint: Color = COLORS.get(champion, Color.WHITE)
	var track := Rect2(0, 2, size.x, 12)
	if champion in ["Luminary", "Outlaw"]:
		var segment := (size.x - 12) / 3.0
		for i in range(3):
			var cell := Rect2(i * (segment + 6), 2, segment, 12)
			draw_style_box(fill_style if i < amount else track_style, cell)
			draw_rect(cell, tint if i < amount else Color("55647b"), false, 1)
	else:
		draw_style_box(track_style, track)
		if amount > 0:
			draw_style_box(fill_style, Rect2(track.position, Vector2(size.x * clampf(amount / maximum, 0, 1), 12)))
		for threshold in thresholds:
			var x: float = size.x * float(threshold) / maximum
			draw_line(Vector2(x, 0), Vector2(x, 16), Color.WHITE if amount >= threshold else Color("7a879c"), 2)
func box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style
