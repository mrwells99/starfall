extends "res://scripts/outlaw_movement_art.gd"
## Shared Living balance B with native right-hand gun carrying and action priorities.
var jump_life=preload("res://scripts/shared_jump.gd").new()
var omni_jump=jump_life.omni_jump

func build(host:Node3D,color:Color)->void:
	super.build(host,color)
	jump_life.build(self,"Outlaw")

func ordinary_jump_allowed(actor)->bool:
	var pending_attack:bool=action_serial>=0 and action_serial!=actor.identity.outlaw_action_serial and actor.identity.outlaw_action in ["gun","knife"]
	return actor.hp>0 and actor.stunned<=0 and actor.casting<0 and not showing_roll(actor) and not actor.identity.backflip_active and shot_left<=0 and knife_left<=0 and not pending_attack and test_aim_weight<=0 and actor.charge.is_empty() and lasso_pose.Lasso.state(actor).is_empty() and not lasso_pose.Lasso.knockdown_active(actor) and lasso_pose.phase.is_empty() and lasso_pose.blend_time>=.10

func animate(host:Node3D,delta:float,actor:CharacterBody3D)->void:
	omni_jump.begin_frame(self,actor,delta,ordinary_jump_allowed(actor),false)
	super.animate(host,delta,actor)
	jump_life.finish_frame(self,actor,delta)

func override_clip(desired:String,alive:bool,stunned:bool,delta:float)->String:
	var original:=super.override_clip(desired,alive,stunned,delta)
	if original.begins_with("Jump") and omni_jump.allowed and alive and not stunned and active_actor!=null:
		return locomotion.choose(filtered_speed,active_actor.walking,Outlaw.severe_slowed(active_actor),false)
	return original
