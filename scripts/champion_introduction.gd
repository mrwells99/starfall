extends VBoxContainer
## Selection guidance; full ability tooltips reuse the live kit descriptions.
const GUIDES := {
	"Ember": ["RANGED BURST", "Build pressure with brands, then cash them in for a fiery burst. Keep space with Blink.", "HEAT · Build with Kindle, Flashpoint and Stoke. Spend it on Supernova or Cinderstep.", ["Kindle", "Flashpoint", "Supernova"]],
	"Vanguard": ["MELEE PRESSURE", "Stay close, expose your target and deliver a heavy finisher. Protect allies under pressure.", "RESOLVE · Build with Sundering Blow. Spend it on Oathbreaker or your defensive abilities.", ["Sundering Blow", "Oathbreaker", "Intercede"]],
	"Luminary": ["TEAM HEALER", "Keep allies alive, remove dangerous effects and prepare an emergency save.", "STARS · Place up to three Guiding Stars on allies. Falling Star consumes them to heal.", ["Guiding Star", "Falling Star", "Last Light"]],
	"Fulcrum": ["CONTROL & DISPLACEMENT", "Shape the fight with gravity. Move enemies, deny space and set up your team's attacks.", "MEDITATION · Build with Entropy damage. Save it to empower Collapse or spend it on Starfall.", ["Entropy", "Collapse", "Starfall"]]
}
var game
var title: Label
var summary: Label
var resource: Label
var rows: Array[Button] = []
var all_button: Button
var return_state := "online"
var library := false
var list: VBoxContainer
var scroll: ScrollContainer
var tooltip: PanelContainer
var hovered := -1
var selected := ""
func install(arena) -> void:
	game = arena
	custom_minimum_size.x = 300
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 7)
	title = game.add_label(self, "", 16)
	summary = game.add_label(self, "", 13)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource = game.add_label(self, "", 12)
	resource.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource.add_theme_color_override("font_color", game.UI_TEXT_DIM)
	tooltip = preload("res://scripts/ability_tooltip.gd").new()
	game.ui.add_child(tooltip)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): clear_hover())
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in range(game.Kits.KIT_SIZE):
		var row := Button.new()
		game.style_button(row)
		list.add_child(row)
		row.mouse_entered.connect(func(): show_hover(i))
		row.mouse_exited.connect(clear_hover)
		row.custom_minimum_size.y = 42
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("icon_max_width", 32)
		row.expand_icon = true
		rows.append(row)
	all_button = game.add_button(self, "All Abilities", func():
		if library:
			game.menu_state = return_state
		else:
			return_state = game.menu_state
			game.menu_state = "abilities"
		game.refresh_menu())

func show_champion(champion: String, active: bool) -> void:
	visible = active
	var full: bool = game.menu_state == "abilities"
	if not active or (selected == champion and library == full): return
	library = full
	all_button.text = "Back" if library else "All Abilities"
	scroll.custom_minimum_size.y = 300 if library else 160
	scroll.scroll_vertical = 0
	clear_hover()
	selected = champion
	var guide: Array = GUIDES[champion]
	title.text = guide[0]
	title.add_theme_color_override("font_color", game.Kits.color(champion))
	summary.text = guide[1]
	resource.text = guide[2]
	var kit: Array = game.Kits.get_kit(champion)
	var shown: Array = kit if library else kit.filter(func(spell): return spell.name in guide[3])
	for i in range(rows.size()):
		rows[i].visible = i < shown.size()
		if i >= shown.size(): continue
		var spell: Dictionary = shown[i]
		rows[i].text = spell.name
		rows[i].icon = game.AbilityArt.texture_for(spell.name, champion)
		rows[i].set_meta("ability", spell)

func show_hover(index: int) -> void:
	if not is_visible_in_tree() or not rows[index].has_meta("ability"): return
	hovered = index
	tooltip.present_illustrated(rows[index].get_meta("ability"), selected, rows[index].icon, game.ui.get_local_mouse_position(), game.ui.size)

func clear_hover() -> void:
	hovered = -1
	if is_instance_valid(tooltip): tooltip.hide()

func _process(_delta: float) -> void:
	if hovered >= 0:
		if not is_visible_in_tree(): clear_hover()
		else: show_hover(hovered)
