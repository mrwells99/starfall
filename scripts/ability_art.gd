extends RefCounted

# Art is presentation data; it never enters combat kits or network snapshots.
# Shared ability names intentionally share art (Mend on Ember and Vanguard).
const PATHS := {
	"Firebolt": "res://assets/icons/abilities/firebolt.png",
	"Flare": "res://assets/icons/abilities/flare.png",
	"Disrupt": "res://assets/icons/abilities/disrupt.png",
	"Stasis": "res://assets/icons/abilities/stasis.png",
	"Ward": "res://assets/icons/abilities/ward.png",
	"Mend": "res://assets/icons/abilities/mend.png",
	"Blink": "res://assets/icons/abilities/blink.png",
	"Cleave": "res://assets/icons/abilities/cleave.png",
	"Crush": "res://assets/icons/abilities/crush.png",
	"Pummel": "res://assets/icons/abilities/pummel.png",
	"Bash": "res://assets/icons/abilities/bash.png",
	"Iron Skin": "res://assets/icons/abilities/iron_skin.png",
	"Charge": "res://assets/icons/abilities/charge.png",
	"Smite": "res://assets/icons/abilities/smite.png",
	"Renewal": "res://assets/icons/abilities/renewal.png",
	"Dispel": "res://assets/icons/abilities/dispel.png",
	"Rebuke": "res://assets/icons/abilities/rebuke.png",
	"Sanctuary": "res://assets/icons/abilities/sanctuary.png",
	"Greater Heal": "res://assets/icons/abilities/greater_heal.png",
	"Grace": "res://assets/icons/abilities/grace.png",
}
static var textures: Dictionary = {}

static func texture_for(ability_name: String) -> Texture2D:
	if not PATHS.has(ability_name):
		return null
	if not textures.has(ability_name):
		textures[ability_name] = load(PATHS[ability_name])
	return textures[ability_name]

static func attach(button: Button) -> TextureRect:
	var art := TextureRect.new()
	art.name = "AbilityArt"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 3
	art.offset_top = 3
	art.offset_right = -3
	art.offset_bottom = -3
	# Frames are engine-rendered, so hover/focus stay visible around the art.
	for state in ["normal", "hover", "pressed", "focus"]:
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color("111321")
		frame.border_color = Color("45435e")
		frame.set_border_width_all(2)
		if state == "hover":
			frame.border_color = Color("c4b4ef")
		elif state == "pressed":
			frame.border_color = Color("f4c778")
		elif state == "focus":
			frame.bg_color = Color.TRANSPARENT
			frame.border_color = Color("f4c778")
		button.add_theme_stylebox_override(state, frame)
	return art
