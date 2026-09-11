extends Node3D
## One reusable cast row; shares the health plate's camera-facing transform.
const AbilityArt = preload("res://scripts/ability_art.gd")
const WIDTH := 1.9
const HEIGHT := 0.30
const FILL_WIDTH := WIDTH - 0.06
const ICON_SIZE := 0.34
const NORMAL_COLOR := Color("c7a256")
var fill: MeshInstance3D
var fill_material: StandardMaterial3D
var icon: Sprite3D
var title: Label3D
var fraction := 0.0
var spell_key := ""

func quad(dimensions: Vector2, color: Color, depth: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := QuadMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.position.z = depth
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material_override = material
	add_child(mesh)
	return mesh

func install() -> void:
	name = "NameplateCast"
	position.y = -0.43
	hide()
	quad(Vector2(WIDTH, HEIGHT), Color("101321"), 0.01)
	fill = quad(Vector2(FILL_WIDTH, HEIGHT - 0.06), NORMAL_COLOR, 0.02)
	fill_material = fill.material_override
	var icon_edge := quad(Vector2.ONE * (ICON_SIZE + 0.04), Color("101321"), 0.01)
	icon_edge.position.x = -WIDTH * 0.5 - ICON_SIZE * 0.5 - 0.04
	icon = Sprite3D.new()
	icon.position = Vector3(icon_edge.position.x, 0, 0.03)
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(icon)
	title = Label3D.new()
	title.position.z = 0.04
	title.font = ThemeDB.fallback_font
	title.font_size = 48
	title.outline_size = 8
	title.modulate = Color.WHITE
	title.outline_modulate = Color.BLACK
	add_child(title)

func sync(actor, tint: Color = NORMAL_COLOR) -> void:
	visible = actor.hp > 0 and not actor.training_dummy and actor.casting >= 0 and actor.casting < actor.kit.size() and actor.cast_left > 0
	if not visible: return
	var spell: Dictionary = actor.kit[actor.casting]
	var duration: float = spell.get("cast", 0.0)
	if duration <= 0:
		hide()
		return
	fraction = clampf(1.0 - actor.cast_left / duration, 0.0, 1.0)
	fill.visible = fraction > 0
	fill.scale.x = maxf(0.001, fraction)
	fill.position.x = -FILL_WIDTH * 0.5 * (1.0 - fraction)
	if fill_material.albedo_color != tint: fill_material.albedo_color = tint
	var key: String = actor.champion + "/" + str(spell.name)
	if key != spell_key:
		spell_key = key
		title.text = spell.name
		# Shrink long names to fit this fixed-width row rather than widening
		# the health plate or truncating the ability's identity.
		var text_width: float = title.font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.font_size).x
		title.pixel_size = minf(0.005, (FILL_WIDTH - 0.08) / maxf(1, text_width))
		icon.texture = AbilityArt.texture_for(spell.name, actor.champion)
		icon.visible = icon.texture != null
		if icon.texture != null: icon.pixel_size = ICON_SIZE / maxf(1, icon.texture.get_width())
