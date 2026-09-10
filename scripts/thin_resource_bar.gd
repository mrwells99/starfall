extends Control
## Text-free roster resource strip; redraw only when its displayed value changes.
const COLORS = preload("res://scripts/resource_meter.gd").COLORS
var fraction := -1.0
var tint := Color.WHITE
static func value(actor) -> float:
	if actor.champion == "Luminary": return clampf(actor.identity.stars.size() / 3.0, 0, 1)
	var field: String = {"Ember": "heat", "Vanguard": "resolve", "Fulcrum": "meditation"}.get(actor.champion, "")
	return clampf(float(actor.identity.get(field, 0)) / 100.0, 0, 1)
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func sync(actor) -> void:
	visible = actor.hp > 0 and not actor.training_dummy
	var next := value(actor)
	var color: Color = COLORS.get(actor.champion, Color.WHITE)
	if next != fraction or color != tint:
		fraction = next
		tint = color
		queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("141c2b"))
	if fraction > 0: draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fraction, size.y)), tint)
