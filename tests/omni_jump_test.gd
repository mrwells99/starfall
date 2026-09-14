extends SceneTree
const Math=preload("res://scripts/null_movement_blend.gd")
const Bodies=preload("res://scripts/body_hitboxes.gd")
var checks:=0
var failures:=0
var maximum_error:=0.0
var maximum_length:=0.0
var frames:=0
var results:=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run()->void:
	for title in ["Null","Outlaw"]:
		var items:=[]
		for visible in [true,false]:
			var actor=load("res://scripts/combatant.gd").new();root.add_child(actor);actor.setup(items.size()+1,1,0,title,visible);actor.setup_hitboxes();actor.presentation_grounded=true
			var art=actor.champion_model.get(title.to_lower()+"_art") if visible else actor.hitbox_pose.art
			var rests:=[];for b in art.skeleton.get_bone_count():rests.append(art.skeleton.get_bone_rest(b))
			items.append({"actor":actor,"art":art,"rests":rests,"times":[]})
		for low in ([false,true] if title=="Null" else [false]):
			for sector in range(-1,8):
				for tick in 150:
					var t:=tick/60.0;var air:=t>=.5 and t<1.2;var age:=t-.5
					var angle:=maxi(sector,0)*PI/4.0
					if sector==2 and air:angle=PI/2 if tick%8<4 else -PI/2
					var speed:float=0 if sector<0 else (3.591 if sector in [3,4,5] else 6.1425)
					if low:speed*=.8
					for item in items:
						var actor=item.actor;var art=item.art
						actor.velocity=Vector3(sin(angle),0,-cos(angle))*speed;actor.position+=actor.velocity/60.0
						actor.presentation_grounded=not air
						if title=="Null":actor.identity.stealth=low
						actor.position.y=7*age-10*age*age if air else 0;actor.velocity.y=7-20*age if air else 0
						var before:=[actor.transform,actor.velocity,actor.identity.duplicate(true),actor.hp,actor.cooldowns.duplicate(),actor.presentation_grounded]
						var start:=Time.get_ticks_usec()
						if actor.champion_model!=null:actor.champion_model.animate(1.0/60,actor);actor.body_hitboxes.update()
						else:actor.update_hitboxes(1.0/60)
						item.times.append(Time.get_ticks_usec()-start)
						check(before==[actor.transform,actor.velocity,actor.identity,actor.hp,actor.cooldowns,actor.presentation_grounded],title+" animation never writes actor/gameplay state")
						for b in art.skeleton.get_bone_count():
							check(art.skeleton.get_bone_pose(b).is_finite() and art.skeleton.get_bone_rest(b)==item.rests[b],title+" finite pose/unchanged anatomy")
							var bn:String=art.skeleton.get_bone_name(b)
							if "shin." in bn or "foot." in bn or "forearm." in bn or "hand." in bn:
								maximum_length=maxf(maximum_length,absf(art.skeleton.get_bone_pose_position(b).length()-item.rests[b].origin.length()))
					for i in 38:maximum_error=maxf(maximum_error,items[0].actor.body_hitboxes.points[i].distance_to(items[1].actor.body_hitboxes.points[i]))
					frames+=1
		var actor=items[0].actor;var art=items[0].art
		check(art.omni_jump.jump_frames>300,title+" installed layer actually animated")
		for state in ["cast","stun","death","charge","special","attack","lasso"]:
			actor.casting=-1;actor.stunned=0;actor.hp=1500;actor.charge={}
			actor.identity.lasso_knockdown={}
			if title=="Null":actor.identity.null_vantage={};art.strike_left=0
			else:actor.identity.roll_left=0;actor.identity.backflip_active=false;art.shot_left=0
			match state:
				"cast":actor.casting=0
				"stun":actor.stunned=1
				"death":actor.hp=0
				"charge":actor.charge={"test":true}
				"special":
					if title=="Null":actor.identity.null_vantage={"phase":"dive"}
					else:actor.identity.backflip_active=true
				"attack":
					if title=="Null":art.strike_left=.3
					else:art.shot_left=.3
				"lasso":
					actor.identity.lasso_knockdown={"left":1.0,"total":1.0,"source":"test","owner":1}
					actor.cc_effects={"stun":{"source":"test","lasso_owner":1}}
			check(not art.ordinary_jump_allowed(actor),title+" native "+state+" has priority")
		var times:Array=items[1].times;var sum:=0.0;for sample in times:sum+=sample
		times.sort()
		results.append({"character":title,"compact_pose_and_capsules_mean_us":sum/times.size(),"p95_us":times[int(times.size()*.95)]})
		for item in items:item.actor.free()
	check(maximum_error<.0005,"visible/server full directional jumps and landing")
	check(maximum_length<.00001,"fixed limb lengths preserved")
	print("Maximum body endpoint difference: ",maximum_error," meters")
	print("OMNI_JUMP_REPORT ",JSON.stringify({"frames":frames,"maximum_endpoint_error_m":maximum_error,"maximum_limb_length_error_m":maximum_length,"timing":results,"engine":Engine.get_version_info().string}))
	print("Omni jump checks: %d passed / %d total"%[checks-failures,checks])
	quit(1 if failures else 0)
