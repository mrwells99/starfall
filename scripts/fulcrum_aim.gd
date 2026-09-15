extends RefCounted
## Local ground-line aiming; the existing ordered action RPC carries only yaw.
var game
var enabled := false
var committing := false
var committed := false
var elapsed := 0.0
var committed_yaw := 0.0
var bar_slot := -1
var saved_length := 9.0
var saved_position := Vector3.ZERO
var saved_pitch := -.38
var saved_fov := 75.0
var reticle: Control
var guide: MeshInstance3D

func setup(host) -> void:
	game=host
	reticle=load("res://scripts/aim_reticle.gd").new(); reticle.name="DivideReticle"; game.ui.add_child(reticle); reticle.hide()
	guide=MeshInstance3D.new(); guide.name="DivideAimGuide"
	var mesh := BoxMesh.new(); mesh.size=Vector3(3,.025,15); guide.mesh=mesh
	var material := StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.albedo_color=Color(.6,.3,1,.15)
	material.no_depth_test=false; guide.material_override=material
	game.add_child(guide); guide.hide()

func toggle(slot: int) -> void:
	if enabled: cancel(); return
	if not game.movement_controls.camera_active() or not game.actors.has(game.local_id): return
	var actor=game.actors[game.local_id]
	var ability: int = game.kit_slot(slot)
	var reason: String = game.ability_block_reason(actor,ability,actor.actor_id)
	if not reason.is_empty(): game.feedback(actor,reason); return
	bar_slot=slot; enabled=true; committed=false; elapsed=0
	saved_length=game.arm.spring_length; saved_position=game.arm.position; saved_pitch=game.arm.rotation.x; saved_fov=game.camera.fov
	game.movement_controls.left=false; game.movement_controls.zoom_velocity=0; game.capture_mouse()
	reticle.show(); guide.show()

func reset() -> void:
	if enabled and game!=null:
		game.arm.spring_length=saved_length; game.arm.position=saved_position; game.arm.rotation.x=saved_pitch; game.camera.fov=saved_fov
		game.release_mouse()
	enabled=false; committed=false; committing=false
	if is_instance_valid(reticle): reticle.hide()
	if is_instance_valid(guide): guide.hide()

func cancel() -> void:
	if committed and game.actors.has(game.local_id):
		if game.authoritative(): game.cancel_own_cast(game.actors[game.local_id],"")
		else:
			game.action_seq+=1
			game.deliver_action(game.epoch,game.action_seq,-1,game.selected_id)
	reset()

func tick(delta: float) -> void:
	if not enabled: return
	if not game.movement_controls.camera_active() or not game.actors.has(game.local_id): reset(); return
	var actor=game.actors[game.local_id]
	if actor.hp<=0 or actor.stunned>0 or game.CC.spell_block(actor)>0: reset(); return
	elapsed+=delta
	if committed and elapsed>.12 and actor.casting<0:
		# Allow a delayed server response before leaving an accepted charge.
		if game.authoritative() or actor.identity.divide_ready<=0 or elapsed>1.5: reset(); return
	if not committed and actor.identity.divide_ready<=0: reset(); return
	if committed: game.pivot.rotation.y=committed_yaw
	game.local_yaw=game.pivot.rotation.y
	guide.position=actor.position+Vector3.UP*.08+Basis(Vector3.UP,game.pivot.rotation.y)*Vector3(0,0,-7.5)
	guide.rotation.y=game.pivot.rotation.y

func apply_camera() -> void:
	if not enabled: return
	game.arm.spring_length=2.5; game.arm.position=Vector3(.65,0,0); game.arm.rotation.x=-.12; game.camera.fov=65

func input(event: InputEvent) -> bool:
	if not enabled: return false
	if event is InputEventMouseMotion:
		if not committed: game.pivot.rotation.y-=event.screen_relative.x*.004*game.player_options.mouse_sensitivity()
		return true
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		cancel(); return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and not committed:
			committed_yaw=game.pivot.rotation.y
			committing=true; game.local_yaw=committed_yaw; game.send_action(bar_slot); committing=false
			committed=true; elapsed=0
		return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		if event.pressed: cancel()
		return true
	return false
