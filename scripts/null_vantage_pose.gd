extends RefCounted
## Vantage-only layer over the accepted JumpStart/Loop/Land library clips.
## Directions use a body-relative frame, with L on +X: no crossed elbows.
## Shared by the visible character and the compact server rig; no root motion.
var rig: Skeleton3D
var bones := {}

func build(skeleton: Skeleton3D) -> void:
	rig=skeleton
	for name in ["DEF-hips","DEF-spine.001","DEF-spine.002","DEF-neck","DEF-head"]:
		bones[name]=rig.find_bone(name)
	for side in ["L","R"]:
		for part in ["upper_arm","forearm","hand","thigh","shin"]:
			var name: String="DEF-"+part+"."+side
			bones[name]=rig.find_bone(name)

func apply(phase: String, elapsed: float, direction: Vector3) -> void:
	var anticipation:=smoothstep(.20,.50,elapsed) if phase=="lift" else 1.0
	var breath:=sin(elapsed*7.5)
	var lean:=lerpf(-.10,.52,anticipation)
	if phase=="dive":
		# A forward attack, not the previous almost-inverted rigid plank.
		lean=clampf(.75+atan2(-direction.y,Vector2(direction.x,direction.z).length())*.52,.72,1.38)
		lean+=.025*sin(elapsed*8.0)
	elif phase=="recover":lean=lerpf(.48,0.0,smoothstep(0,.18,elapsed))
	rotate("DEF-hips",Vector3.RIGHT,lean)
	rotate("DEF-spine.001",Vector3.RIGHT,.025*breath)
	rotate("DEF-spine.002",Vector3.UP,.025*sin(elapsed*6.0))
	rotate("DEF-neck",Vector3.RIGHT,-.10*anticipation+.02*breath)
	var frame:=Basis(Quaternion(Vector3.RIGHT,lean))
	for side in ["L","R"]:
		var sign_x:=1.0 if side=="L" else -1.0
		var stagger:=.09 if side=="L" else -.09
		var flutter:=sin(elapsed*8.0+sign_x*.7)
		var upper:=Vector3(sign_x*(.43+.025*flutter),lerpf(-.48,-.65,anticipation),lerpf(-.12,.20,anticipation))
		var lower:=Vector3(sign_x*.10,lerpf(.80,.48,anticipation)+stagger,.65+.04*breath)
		if phase=="dive":
			upper=Vector3(sign_x*(.38+.025*flutter),-.46+stagger,.68+.025*breath)
			lower=Vector3(sign_x*.08,.42+stagger,.94+.04*flutter)
			# Let the legs extend behind the attack with a little asymmetry.
			aim("DEF-thigh."+side,frame*Vector3(sign_x*.10,-.95,-.12+stagger+.025*flutter))
			aim("DEF-shin."+side,frame*Vector3(sign_x*.025,-.88,-.45-stagger+.03*breath))
		elif phase=="recover":
			upper=Vector3(sign_x*.35,-.8,.25)
			lower=Vector3(sign_x*.08,-.25,.9)
		aim("DEF-upper_arm."+side,frame*upper)
		aim("DEF-forearm."+side,frame*lower)
		aim("DEF-hand."+side,frame*lower)

func rotate(name: String, axis: Vector3, angle: float) -> void:
	var index: int=bones[name]
	if index>=0:rig.set_bone_pose_rotation(index,Quaternion(axis,angle)*rig.get_bone_pose_rotation(index))

func aim(name: String, direction: Vector3) -> void:
	var index: int=bones[name]
	if index<0:return
	var current:=rig.get_bone_global_pose(index).basis.orthonormalized()
	var parent:=rig.get_bone_global_pose(rig.get_bone_parent(index)).basis.orthonormalized()
	var rotation:=Quaternion(current.y.normalized(),direction.normalized())*current.get_rotation_quaternion()
	rig.set_bone_pose_rotation(index,parent.get_rotation_quaternion().inverse()*rotation)
