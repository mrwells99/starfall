extends Control
## Cached 2D resource readout. It follows replicated class state, never predicts costs.
const COLORS := {"Ember": Color("ff984f"), "Vanguard": Color("f2cf74"), "Fulcrum": Color("bc96ff"), "Luminary": Color("91e6c0")}
var champion := ""
var amount := 0.0
var thresholds: Array = []
var cache := ""
var track_style := box(Color("182334"))
var fill_style := box(Color.WHITE)
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func sync(actor, _is_personal: bool) -> void:
	champion = actor.champion
	var state: Dictionary = actor.identity
	fill_style.bg_color = COLORS.get(champion, Color.WHITE)
	amount = float(state.get({"Ember":"heat", "Vanguard":"resolve", "Fulcrum":"meditation"}.get(champion, ""), 0))
	thresholds = {"Ember":[20, 40], "Vanguard":[40], "Fulcrum":[50, 75]}.get(champion, [])
	if champion == "Luminary": amount = state.stars.size()
	var key := "%s:%s:%s" % [champion, amount, size]
	if key != cache:
		cache = key
		queue_redraw()
func _draw() -> void:
	if champion.is_empty(): return
	var tint: Color = COLORS.get(champion, Color.WHITE)
	var track := Rect2(0, 2, size.x, 12)
	if champion == "Luminary":
		var segment := (size.x - 12) / 3.0
		for i in range(3):
			var cell := Rect2(i * (segment + 6), 2, segment, 12)
			draw_style_box(fill_style if i < amount else track_style, cell)
			draw_rect(cell, tint if i < amount else Color("55647b"), false, 1)
	else:
		draw_style_box(track_style, track)
		if amount > 0:
			draw_style_box(fill_style, Rect2(track.position, Vector2(size.x * clampf(amount / 100.0, 0, 1), 12)))
		for threshold in thresholds:
			var x: float = size.x * float(threshold) / 100.0
			draw_line(Vector2(x, 0), Vector2(x, 16), Color.WHITE if amount >= threshold else Color("7a879c"), 2)
func box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style
