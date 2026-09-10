extends Control
## Fixed inset effect tiles with a cast strip below the roster health bar.
var game
var cast: ProgressBar
var strip: HBoxContainer
var actor_id := -1
func install(arena) -> void:
	game = arena
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_bottom = 0
	offset_top = 4
	offset_bottom = 44
	offset_left = 4
	offset_right = -4
	cast = game.styled_bar(Color("c2a1f0"), 15)
	cast.custom_minimum_size = Vector2(0, 15)
	add_child(cast)
	cast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cast.offset_top = 42
	cast.offset_bottom = 57
	cast.offset_left = 0
	cast.offset_right = 0
	(cast.get_child(0) as Label).add_theme_font_size_override("font_size", 11)
	strip = HBoxContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_constant_override("separation", 2)
	add_child(strip)
	for i in range(6):
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(20, 20)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var edge := StyleBoxFlat.new()
		edge.bg_color = Color("101321")
		edge.set_border_width_all(1)
		chip.add_theme_stylebox_override("panel", edge)
		strip.add_child(chip)
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(art)
		var timer := Label.new()
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		timer.add_theme_font_size_override("font_size", 11)
		timer.add_theme_color_override("font_color", Color.WHITE)
		timer.add_theme_color_override("font_outline_color", Color.BLACK)
		timer.add_theme_constant_override("outline_size", 5)
		timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(timer)
		chip.hide()
func sync(actor) -> void:
	actor_id = actor.actor_id
	var interrupted: bool = Time.get_ticks_msec() < int(game.combat_text.interrupts.get(actor_id, 0))
	cast.visible = actor.hp > 0 and (actor.casting >= 0 or interrupted)
	if cast.visible:
		var text := "INTERRUPTED"
		cast.value = 100
		if not interrupted and actor.casting >= 0:
			var spell: Dictionary = actor.kit[actor.casting]
			cast.value = 100 * (1 - actor.cast_left / maxf(0.01, spell.cast))
			text = "%s · %.1fs" % [spell.name, actor.cast_left]
		(cast.get_child(0) as Label).text = text
		var fill: StyleBoxFlat = cast.get_theme_stylebox("fill")
		var cast_color := Color("854657") if interrupted else Color("675183")
		if fill.bg_color != cast_color: fill.bg_color = cast_color
	strip.position = Vector2(3, 1)
	var effects: Array = game.Auras.active(actor, game.actors.values(), game.local_id)
	effects.sort_custom(func(a, b): return priority(a) > priority(b))
	if actor.hp > 0 and actor.hp <= 30:
		effects.push_front({"key": "low_hp", "name": "Low health", "source": "Mend", "remaining": 0, "color": Color("ff7d92"), "description": "Health is at or below 30 HP."})
	for i in range(strip.get_child_count()):
		var chip: PanelContainer = strip.get_child(i)
		chip.visible = i < effects.size()
		if not chip.visible:
			chip.remove_meta("aura")
			continue
		var aura: Dictionary = effects[i]
		chip.set_meta("aura", aura)
		var source: String = aura.get("source", "")
		var texture = game.AbilityArt.texture_for(source)
		if texture == null: texture = game.AbilityArt.texture_for(aura.name)
		if texture == null: texture = game.AbilityArt.texture_for("Stasis" if aura.key == "stun" else ("Disrupt" if aura.key == "lockout" else "Ward"))
		chip.get_child(0).texture = texture
		chip.get_child(0).modulate = Color("ff7d92") if aura.key == "low_hp" else Color.WHITE
		chip.get_child(1).text = "!" if aura.key == "low_hp" else ("×%d" % int(aura.stacks) if aura.has("stacks") else str(ceili(aura.remaining)))
		var edge: StyleBoxFlat = chip.get_theme_stylebox("panel")
		if edge.border_color != aura.color: edge.border_color = aura.color
func priority(aura: Dictionary) -> int:
	if aura.has("cc") or aura.key == "root": return 3
	if aura.key in ["shield", "last", "hold", "immune", "guard_left"]: return 2
	return 1
