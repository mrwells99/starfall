extends Control

# WoW-style radial cooldown sweep, drawn over a hotbar slot.
#
# The shaded wedge covers the fraction of the cooldown still remaining and
# unwinds clockwise from 12 o'clock, so a slot reads as ready the instant the
# dark area clears. Two tiers, like the game they come from:
#
#   - Ability cooldown: heavy shade plus an OmniCC-style countdown number.
#   - Global cooldown:  light shade, no number. It lasts 1.5s; a number there
#     is unreadable noise.
#
# This runs its own timer. The HUD only refreshes when server state arrives,
# which is well below frame rate, so a node that waited to be told would tick
# in visible steps. sync() supplies the authoritative value whenever one
# arrives and the local clock fills the gaps.

const SWEEP_COLOR := Color(0.02, 0.03, 0.05, 0.74)
const GCD_COLOR := Color(0.10, 0.14, 0.22, 0.62)
const SEGMENTS := 48

var remaining := 0.0
var duration := 0.0
var is_gcd := false
var label: Label
var key_label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("ffe6a8"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.hide()
	add_child(label)
	# Keybind lives in the corner, WoW-style, so the countdown owns the centre.
	key_label = Label.new()
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.position = Vector2(6, 2)
	key_label.add_theme_font_size_override("font_size", 15)
	key_label.add_theme_color_override("font_color", Color("9fb0c2"))
	key_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	key_label.add_theme_constant_override("shadow_offset_x", 1)
	key_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(key_label)

func set_key(text: String) -> void:
	key_label.text = text

# Authoritative state from the server snapshot.
func sync(new_remaining: float, new_duration: float, gcd: bool) -> void:
	remaining = maxf(0.0, new_remaining)
	duration = maxf(0.0, new_duration)
	is_gcd = gcd
	_refresh()

func _process(delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	_refresh()

func _refresh() -> void:
	# A number under the global cooldown flickers through 1.5s of digits, so
	# only ability cooldowns get one.
	label.visible = remaining > 0.0 and not is_gcd
	if label.visible:
		label.text = format_time(remaining)
	queue_redraw()

# OmniCC-style: minutes when long, whole seconds when short, tenths at the end.
static func format_time(t: float) -> String:
	if t >= 60.0:
		return "%dm" % int(ceil(t / 60.0))
	if t >= 10.0:
		return "%d" % int(ceil(t))
	return "%.1f" % t

func _draw() -> void:
	if remaining <= 0.0 or duration <= 0.0:
		return
	var fraction := clampf(remaining / duration, 0.0, 1.0)
	var centre := size * 0.5
	# Half the diagonal, so the wedge reaches the corners of a non-square slot
	# instead of leaving lit crescents behind.
	var radius := size.length() * 0.5
	var top := -PI * 0.5
	var begin := top + TAU * (1.0 - fraction)
	var sweep := TAU * fraction
	var points := PackedVector2Array()
	points.append(centre)
	for i in range(SEGMENTS + 1):
		var angle := begin + sweep * (float(i) / float(SEGMENTS))
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, GCD_COLOR if is_gcd else SWEEP_COLOR)
