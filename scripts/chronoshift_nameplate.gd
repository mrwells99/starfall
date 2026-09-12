extends Node3D
## Pooled reset timers inherit the health pivot's camera facing and concealment.
const Status = preload("res://scripts/chronoshift_status.gd")
const AbilityArt = preload("res://scripts/ability_art.gd")
const COLUMNS := 6
const SPACING := 0.36
var chips: Array[Node3D] = []
var heading: Label3D

func install() -> void:
	name = "ChronoshiftTimers"
	position.y = 0.83
	heading = Label3D.new()
	heading.text = "CHRONOSHIFT"
	heading.font_size = 32
	heading.pixel_size = 0.0032
	heading.modulate = Color("c7d3dc")
	heading.outline_size = 8
	heading.position = Vector3(0, 0.39, 0.04)
	add_child(heading)
	hide()

func add_chip() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var icon := Sprite3D.new()
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.position.z = 0.03
	holder.add_child(icon)
	var timer := Label3D.new()
	timer.position = Vector3(0.06, -0.09, 0.04)
	timer.font_size = 40
	timer.pixel_size = 0.0035
	timer.outline_size = 10
	holder.add_child(timer)
	chips.append(holder)

func sync(actor) -> void:
	var slots := Status.active_slots(actor)
	visible = not slots.is_empty()
	if not visible: return
	while chips.size() < actor.kit.size(): add_chip()
	var rows := ceili(slots.size() / float(COLUMNS))
	heading.position.y = (rows - 1) * SPACING + 0.27
	for i in range(chips.size()):
		var holder := chips[i]
		holder.visible = i < slots.size()
		if not holder.visible: continue
		var slot := slots[i]
		var count := mini(COLUMNS, slots.size() - (i / COLUMNS) * COLUMNS)
		holder.position = Vector3((i % COLUMNS - (count - 1) * 0.5) * SPACING, (i / COLUMNS) * SPACING, 0)
		var icon := holder.get_child(0) as Sprite3D
		icon.texture = AbilityArt.texture_for(actor.kit[slot].name, actor.champion)
		icon.visible = icon.texture != null
		if icon.texture != null: icon.pixel_size = 0.30 / maxf(1, icon.texture.get_width())
		(holder.get_child(1) as Label3D).text = str(ceili(actor.identity.chronoshift_locks[slot]))
		holder.set_meta("ability_slot", slot)
