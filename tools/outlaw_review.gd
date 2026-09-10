extends "res://tools/model_forge_review.gd"
## Review the actual imported model and runtime layers on the second monitor.
func run() -> void:
	await super.run()
	DisplayServer.window_set_title("Outlaw — model, weapons and movement review")
	picker.clear(); picker.add_item("Outlaw")
	sequence = [["Idle",2.0,Vector3.ZERO,0.0], ["Walk",1.5,Vector3.FORWARD,1.5],
		["Run",1.5,Vector3.FORWARD,6.5], ["Left",1.2,Vector3.LEFT,6.5],
		["Backpedal",1.5,Vector3.BACK,3.8], ["Jump",.7,Vector3.ZERO,0.0],
		["Idle",.5,Vector3.ZERO,0.0], ["Roll",.55,Vector3.RIGHT,0.0],
		["Idle",.4,Vector3.ZERO,0.0], ["Backflip",1.2,Vector3.ZERO,0.0],
		["Idle",.5,Vector3.ZERO,0.0], ["Severe",.65,Vector3.ZERO,0.0],
		["Starshot",.8,Vector3.ZERO,0.0], ["Detonation",3.0,Vector3.FORWARD,6.5],
		["Deadeye",3.0,Vector3.FORWARD,3.25], ["Idle",1.5,Vector3.ZERO,0.0]]
	set_view("Three-quarter")
	if "--outlaw-capture" in OS.get_cmdline_user_args():
		ready = false
		for view in ["Front","Back","Side","Three-quarter"]:
			set_view(view); simulate("Idle",.3,Vector3.ZERO,0); await capture(view.to_lower())
		set_view("Three-quarter")
		for item in [["run","Run",.3,Vector3.FORWARD,6.5],["backpedal","Backpedal",.4,Vector3.BACK,3.8],
			["roll","Roll",.22,Vector3.RIGHT,0.0],["backflip","Backflip",.55,Vector3.ZERO,0.0],
			["knife-strike","Severe",.26,Vector3.ZERO,0.0],["gun-aim","Starshot",.4,Vector3.ZERO,0.0],
			["moving-channel","Detonation",.45,Vector3.FORWARD,6.5],["deadeye","Deadeye",.5,Vector3.FORWARD,3.25]]:
			simulate(item[1],item[2],item[3],item[4]); await capture(item[0])
		print("OUTLAW_REVIEW_CAPTURED"); quit()

func select_class(_name: String) -> void:
	if actor != null: stage.remove_child(actor); actor.queue_free()
	title = "Outlaw"
	actor = load("res://scripts/combatant.gd").new(); stage.add_child(actor); actor.setup(1,1,0,title)
	actor.set_physics_process(false); actor.set_process(false)
	if is_instance_valid(actor.nameplate): actor.nameplate.hide()
	actor.health_pivot.hide()
	art = actor.champion_model.outlaw_art
	actor.presentation_grounded = true
	step=0;elapsed=0
	pose("Idle",0,.016,Vector3.ZERO,0)

func pose(label: String,t: float,delta: float,direction: Vector3,velocity: float) -> void:
	var jumping := label in ["Jump","Backflip"]
	var leap := 12.0 if label=="Backflip" else 7.0
	actor.presentation_grounded = not jumping
	actor.presentation_vertical_speed = leap-20*t if jumping else 0.0
	actor.velocity.y = actor.presentation_vertical_speed
	actor.position = Vector3(0,maxf(0,leap*t-10*t*t) if jumping else 0,0)
	actor.identity.backflip_active = label=="Backflip"
	actor.identity.backflip_elapsed = t if label=="Backflip" else 0.0
	actor.identity.roll_left = maxf(.001,.55-t) if label=="Roll" else 0.0
	actor.identity.roll_direction = direction
	actor.casting = {"Starshot":0,"Detonation":8,"Deadeye":9}.get(label,-1)
	actor.cast_left = maxf(0,3-t) if actor.casting>=0 else 0
	actor.walking = label=="Deadeye"
	actor.move_input=Vector2(direction.x,direction.z)
	art.knife_left = maxf(0,.65-t) if label=="Severe" else 0.0
	art.last_position=actor.position-direction*velocity*delta
	actor.champion_model.animate(delta,actor)
	camera.position=camera_home+Vector3.UP*actor.position.y*.65
	camera.look_at(Vector3(0,1.08+actor.position.y*.65,0))
	status.text="OUTLAW · "+label+"\n150% Bowie knife · native closed fist grip"

func capture(label: String) -> void:
	art.skeleton.force_update_all_bone_transforms()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/outlaw-forge-v2/"+label+".png")
