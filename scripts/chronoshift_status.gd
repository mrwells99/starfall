extends Control
## Replicated reset eligibility, independent of the action bar's normal cooldowns.
const AbilityArt = preload("res://scripts/ability_art.gd")
const COLUMNS := 7
const CELL := 29
var heading: Label
var timers: GridContainer
var chips: Array[PanelContainer] = []

static func active_slots(actor) -> Array[int]:
	var slots: Array[int] = []
	if actor.champion != "Null" or actor.hp <= 0: return slots
	var locks: Dictionary = actor.identity.get("chronoshift_locks", {})
	for slot in range(actor.kit.size()):
		if float(locks.get(slot, 0.0)) > 0.0: slots.append(slot)
	return slots

static func description(ability: String) -> String:
	return "Chronoshift cannot refresh %s again until this timer ends. You can still use %s whenever its normal cooldown is ready. This timer is separate from the normal ability cooldown." % [ability, ability]

func install() -> void:
	name = "ChronoshiftStatus"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(0, 20)
	custom_minimum_size = Vector2(220, 52)
	heading = Label.new()
	heading.text = "CHRONOSHIFT RESET"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", Color("becbd5"))
	heading.add_theme_color_override("font_outline_color", Color("090d13"))
	heading.add_theme_constant_override("outline_size", 4)
	add_child(heading)
	timers = GridContainer.new()
	timers.position.y = 17
	timers.columns = COLUMNS
	timers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timers.add_theme_constant_override("h_separation", 3)
	timers.add_theme_constant_override("v_separation", 3)
	add_child(timers)
	hide()

func add_chip() -> void:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2.ONE * CELL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color("101722")
	edge.border_color = Color("8b9dab")
	edge.set_border_width_all(1)
	chip.add_theme_stylebox_override("panel", edge)
	timers.add_child(chip)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	var timer := Label.new()
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	timer.add_theme_font_size_override("font_size", 13)
	timer.add_theme_color_override("font_color", Color.WHITE)
	timer.add_theme_color_override("font_outline_color", Color("090d13"))
	timer.add_theme_constant_override("outline_size", 5)
	chip.add_child(timer)
	chips.append(chip)

func sync(actor) -> void:
	var slots := active_slots(actor)
	visible = not slots.is_empty()
	if not visible: return
	while chips.size() < actor.kit.size(): add_chip()
	var rows := ceili(slots.size() / float(COLUMNS))
	# The state label is below the health/cast bars. Offset by its frame position
	# as well as our own height so this panel finishes just above the health bar.
	var state_line := get_parent() as Control
	var state_offset := state_line.position.y if state_line != null else 0.0
	position = Vector2(0, -state_offset - 17 - rows * (CELL + 3) - 4)
	for i in range(chips.size()):
		var chip := chips[i]
		chip.visible = i < slots.size()
		if not chip.visible:
			chip.remove_meta("aura")
			continue
		var slot := slots[i]
		var spell: Dictionary = actor.kit[slot]
		var remaining: float = actor.identity.chronoshift_locks[slot]
		(chip.get_child(0) as TextureRect).texture = AbilityArt.texture_for(spell.name, actor.champion)
		(chip.get_child(1) as Label).text = str(ceili(remaining))
		chip.set_meta("aura", {"key": "chronoshift_%d" % slot, "name": "%s · Chronoshift reset" % spell.name, "source": spell.name, "remaining": remaining, "description": description(spell.name)})
		chip.set_meta("ability_slot", slot)
