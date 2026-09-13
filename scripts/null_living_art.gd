extends "res://scripts/null_movement_art.gd"
## Approved slight polish of B; original B/A remain in null_movement_art.gd.
const LivingBlend = preload("res://scripts/null_living_blend.gd")

func build(host: Node3D, team_color: Color) -> void:
	super.build(host,team_color)
	pose_blend=LivingBlend.new()
	pose_blend.build(skeleton)
	pose_blend.load_life(load("res://assets/animations/null_idle_life.res"))

func transition_duration(previous: String, next: String) -> float:
	var seconds:=super.transition_duration(previous,next)
	pose_blend.life_low=Locomotion.is_low(next)
	# A tiny timing extension, confined to B's same-stance locomotion path.
	return seconds*1.06 if pose_blend.inertial_enabled else seconds
