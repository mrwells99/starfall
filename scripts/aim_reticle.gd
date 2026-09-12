extends Control
## Created only when a future kit explicitly opts into hitscan aiming.
var confirmed_left := 0.0
var charge_progress := 1.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func confirm_hit() -> void:
	confirmed_left = .12; queue_redraw()

func _process(delta: float) -> void:
	if confirmed_left > 0:
		confirmed_left = maxf(0,confirmed_left-delta); queue_redraw()

func _draw() -> void:
	var center := size*.5
	var color := Color("ffc878") if confirmed_left > 0 else Color("e2edf3")
	if charge_progress < 1.0:
		color = Color("89939f")
		draw_arc(center,14,-PI*.5,-PI*.5+TAU*charge_progress,40,Color("ffc878"),2,true)
	for axis in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		draw_line(center+axis*4,center+axis*9,Color("101824"),4,true)
		draw_line(center+axis*4,center+axis*9,color,1.5,true)
