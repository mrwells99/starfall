extends SceneTree
const Bodies = preload("res://scripts/body_hitboxes.gd")
var checks := 0
var failures := 0
var samples := 0
var rays := 0
var maximum_error := 0.0
var old_usec := 0
var new_usec := 0

# Frozen pre-optimization update, evaluated against the very same live skeleton.
# This catches identical bugs on both the visible and server paths, which a
# visible/server agreement test alone cannot catch.
class ReferenceBodies extends "res://scripts/body_hitboxes.gd":
	func update() -> void:
		rig.force_update_all_bone_transforms()
		segment(0,bone("thigh.L"),bone("thigh.R"))
		segment(1,bone("spine.001"),bone("spine.002"))
		segment(2,bone("spine.002"),bone("spine.003",Vector3(0,.075,0)))
		segment(3,bone("neck"),bone("head"))
		segment(4,bone("head",Vector3(0,.07,0)),bone("head",Vector3(0,.14,0)))
		for side in 2:
			var suffix: String = ".L" if side == 0 else ".R"
			var k := 5 + side*7
			segment(k,bone("upper_arm"+suffix),bone("upper_arm"+suffix,Vector3(0,.045,0)))
			segment(k+1,bone("upper_arm"+suffix),bone("forearm"+suffix))
			segment(k+2,bone("forearm"+suffix),bone("hand"+suffix))
			segment(k+3,bone("hand"+suffix),bone("hand"+suffix,Vector3(0,.08,0)))
			segment(k+4,bone("thigh"+suffix),bone("shin"+suffix))
			segment(k+5,bone("shin"+suffix),bone("foot"+suffix))
			segment(k+6,bone("foot"+suffix),bone("toe"+suffix))
		bounds = bounds_for(points,radii)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func compare(actor, reference, test_rays: bool) -> bool:
	var optimized = actor.body_hitboxes
	reference.update(); optimized.update()
	samples += 1
	var identical: bool = optimized.points == reference.points and optimized.radii == reference.radii and optimized.bounds == reference.bounds
	for i in optimized.points.size():
		maximum_error = maxf(maximum_error,optimized.points[i].distance_to(reference.points[i]))
	if test_rays:
		# Sample hits, misses, and near-edge rays around every capsule, in both
		# the ordinary and aim-expanded profiles. Trace math is unchanged.
		for part in optimized.radii.size():
			var center: Vector3 = (reference.points[part*2]+reference.points[part*2+1])*.5
			for offset in [0.0, reference.radii[part]*.999, reference.radii[part]*1.001, 4.0]:
				var origin := center + Vector3(offset,0,-4)
				var plain_old := Bodies.trace(origin,Vector3.BACK,8,reference.points,reference.radii)
				var plain_new := Bodies.trace(origin,Vector3.BACK,8,optimized.points,optimized.radii)
				var aim_old := Bodies.trace_aim(origin,Vector3.BACK,8,reference.points,reference.radii,actor.position)
				var aim_new := Bodies.trace_aim(origin,Vector3.BACK,8,optimized.points,optimized.radii,actor.position)
				identical = identical and plain_old == plain_new and aim_old == aim_new
				rays += 2
	return identical

func run() -> void:
	var host := Node3D.new(); root.add_child(host)
	for title in ["Ember","Luminary","Fulcrum","Vanguard","Outlaw","Null"]:
		var actor = load("res://scripts/combatant.gd").new(); host.add_child(actor)
		actor.setup(1,1,0,title,false); actor.setup_hitboxes()
		var art = actor.hitbox_pose.art
		var reference := ReferenceBodies.new(); reference.setup(art.skeleton,title)
		for state in ["idle","run","strafe","jump","land","mend","cancel","stun","death","revive","teleport","stealth","strike","roll","backflip","vantage"]:
			actor.reset_identity(); actor.casting = -1
			var identical := true
			for frame in 48:
				var t := frame/60.0
				actor.hp = 0 if state == "death" or (state == "revive" and frame<24) else actor.MAX_HEALTH
				actor.stunned = 1.0 if state == "stun" else 0.0
				actor.presentation_grounded = state not in ["jump","backflip"]
				actor.velocity = Vector3(0,7-20*t,0) if state == "jump" else Vector3.ZERO
				actor.presentation_vertical_speed = actor.velocity.y
				actor.rotation.y += .023
				if state == "run": actor.position += Vector3.FORWARD*6.5/60
				if state == "strafe": actor.position += Vector3.LEFT*6.5/60
				if state == "teleport" and frame%8 == 0:
					actor.position = Vector3(frame*2.1,frame*.03,-frame*.7)
					actor.motion_revision += 1
					# A changed ancestor must be observed on the very next update too.
					host.rotation.y += .17; host.position += Vector3(.1,.2,.3)
				actor.casting = -1
				if state == "mend" or (state == "cancel" and frame<24):
					for slot in actor.kit.size():
						if actor.kit[slot].kind == "self_heal": actor.casting = slot
				actor.cast_left = 2.0-t if actor.casting>=0 else 0.0
				if title == "Null":
					actor.identity.stealth = state == "stealth"
					if state == "strike" and frame in [1,24]:
						actor.identity.null_action = "stab" if frame==1 else "backstab"
						actor.identity.null_action_serial += 1
					if state == "vantage": actor.identity.null_vantage={"phase":"lift" if frame<16 else ("dive" if frame<32 else "recover"),"elapsed":t,"direction":Vector3(0,-1,-1).normalized()}
				if title == "Outlaw":
					actor.identity.roll_left = maxf(0,.4-t) if state == "roll" else 0
					actor.identity.roll_animation_left = maxf(0,.6-t) if state == "roll" else 0
					actor.identity.roll_direction = Vector3.RIGHT
					actor.identity.outlaw_action = "roll" if state == "roll" else ""
					actor.identity.backflip_active = state == "backflip"
					actor.identity.backflip_elapsed = t
				if title == "Vanguard" and state == "strike" and frame==1: art.strike()
				actor.hitbox_pose.animate(1.0/60,actor)
				identical = compare(actor,reference,frame in [0,24,47]) and identical
			check(identical,title+" "+state+": exact original endpoints, bounds and hit results")
		# Also sample every library clip; runtime states above exercise overlays.
		var all_clips := true
		for clip in art.player.get_animation_list():
			art.player.play(clip)
			for fraction in [0.0,.25,.5,.75,.99]:
				art.player.seek(art.player.get_animation(clip).length*fraction,true)
				all_clips = compare(actor,reference,false) and all_clips
		check(all_clips,title+": all library clips preserve original hitboxes")
		# Alternate order to reduce first-run/cache bias. This measures the
		# extraction calculation, not the separate animation or network costs.
		for batch in 12:
			for version in ([reference,actor.body_hitboxes] if batch%2==0 else [actor.body_hitboxes,reference]):
				var start := Time.get_ticks_usec()
				for repeat in 150: version.update()
				var duration := Time.get_ticks_usec()-start
				if batch>=2:
					if version == reference: old_usec += duration
					else: new_usec += duration
		actor.free()
	host.free()
	print("Hitbox comparison samples=",samples," rays=",rays," maximum_endpoint_error_m=",maximum_error)
	print("Hitbox extraction benchmark original_ms=",old_usec/9000000.0," optimized_ms=",new_usec/9000000.0," reduction_percent=",100.0*(old_usec-new_usec)/maxi(1,old_usec))
	print("Hitbox optimization checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
