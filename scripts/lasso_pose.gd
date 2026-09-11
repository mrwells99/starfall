extends RefCounted
## Additive action layer, shared by render models and mesh-free damage rigs.
const DATA = preload("res://assets/characters/lasso_motion.tres")
const Lasso = preload("res://scripts/outlaw_lasso.gd")
var rig: Skeleton3D
var indices: Array[int] = []
var previous: Array[Transform3D] = []
var blend_from: Array[Transform3D] = []
var phase := ""
var blend_time := 1.0
var return_yaw := PI

func capture_if_needed(actor) -> void:
	if not phase.is_empty() or not Lasso.state(actor).is_empty() or Lasso.knockdown_active(actor): remember()

func build(skeleton: Skeleton3D) -> void:
	rig = skeleton
	for bone in DATA.bones: indices.append(rig.find_bone(bone))
	remember()

func remember() -> void:
	previous.clear()
	for i in rig.get_bone_count(): previous.append(rig.get_bone_pose(i))

func sample(name: String, fraction: float, arms_only := false) -> void:
	var frames: Array = DATA.clips[name].frames
	var frame: float = clampf(fraction,0,1) * (frames.size()-1)
	var lo := floori(frame)
	var hi := mini(lo+1,frames.size()-1)
	for b in indices.size():
		if arms_only:
			var name_parts: String = DATA.bones[b].get_slice(".",0)
			if name_parts not in ["DEF-shoulder","DEF-upper_arm","DEF-forearm","DEF-hand"]: continue
		if indices[b] >= 0: rig.set_bone_pose(indices[b], frames[lo][b].interpolate_with(frames[hi][b],frame-lo))

func aim_bone(name: String, direction: Vector3) -> void:
	var bone := rig.find_bone(name)
	if bone < 0: return
	var current: Basis = rig.get_bone_global_pose(bone).basis.orthonormalized()
	var parent: Basis = rig.get_bone_global_pose(rig.get_bone_parent(bone)).basis.orthonormalized()
	var rotation := Quaternion(current.y.normalized(),direction.normalized()) * current.get_rotation_quaternion()
	rig.set_bone_pose_rotation(bone,parent.get_rotation_quaternion().inverse()*rotation)

func apply(art, host, actor, delta: float) -> void:
	var s: Dictionary = Lasso.state(actor)
	var next: String = s.get("phase", "") if actor.hp > 0 else ""
	if next == "cast" and not Lasso.casting(actor): next = ""
	if Lasso.knockdown_active(actor): next = "down"
	if next.is_empty() and phase.is_empty() and blend_time >= .10: return
	if next != phase:
		if next.is_empty(): return_yaw = art.model.rotation.y
		blend_from = previous.duplicate()
		blend_time = 0.0
		phase = next
		if next.is_empty(): art.transient_left = 0.0
	if not next.is_empty():
		host.rotation.x = 0; host.rotation.z = 0
		art.model.rotation.y = PI
		if next == "down":
			var k: Dictionary = actor.identity.lasso_knockdown
			var direction: Vector3 = k.get("direction",actor.basis.z)
			art.model.rotation.y = PI + atan2(direction.x,direction.z) - actor.rotation.y
			var progress: float = clampf(1.0 - float(k.left)/float(k.total),0,1)
			# Give fall/get-up more of the existing stun: 35% fall, 16% hold, 49% rise.
			var frame: float = minf(1, progress / .35) if progress < .51 else (1.0-progress)/.49
			sample("Death01",frame)
		elif next == "cast" or next == "rope":
			sample("Spell_Simple_Enter",.85,true)
			var angle: float = (Lasso.CAST - actor.cast_left) * TAU * 3 if next == "cast" else 0.0
			aim_bone("DEF-upper_arm.R",Vector3(.7,.85,.1))
			aim_bone("DEF-forearm.R",Vector3(.3*cos(angle),1,.3*sin(angle)))
		elif next == "pull":
			sample("Roll",0)
			var hips := rig.find_bone("DEF-hips")
			rig.set_bone_pose_rotation(hips,Quaternion(Vector3.RIGHT,-PI*.32)*rig.get_bone_pose_rotation(hips))
			for side in ["L","R"]:
				aim_bone("DEF-thigh."+side, Vector3(-.12 if side=="L" else .12,.1,1))
				aim_bone("DEF-shin."+side,Vector3(0,-.20,1))
				aim_bone("DEF-upper_arm."+side,Vector3(-.4 if side=="L" else .4,-.6,-.3))
				aim_bone("DEF-forearm."+side,Vector3(0,.15,1))
		elif next == "rebound":
			var progress: float = clampf(float(s.elapsed)/Lasso.REBOUND_TIME,0,1)
			sample("Roll",.60*(1-progress))
		if art.get("equipment") != null: art.equipment.apply()
	blend_time += delta
	if next.is_empty(): art.model.rotation.y = lerp_angle(return_yaw,PI,smoothstep(0,.10,blend_time))
	if blend_time < .10 and not blend_from.is_empty():
		var weight := smoothstep(0,.10,blend_time)
		for i in rig.get_bone_count(): rig.set_bone_pose(i,blend_from[i].interpolate_with(rig.get_bone_pose(i),weight))
