extends "res://scripts/model_forge_art.gd"
## Null-specific poses and observer visibility; server uses identical pose layers.
const Null = preload("res://scripts/null_mechanics.gd")
const Locomotion = preload("res://scripts/null_locomotion.gd")
var locomotion = Locomotion.new()
var active_actor
var strike_pose=preload("res://scripts/null_strike_pose.gd").new()
var vantage_pose=preload("res://scripts/null_vantage_pose.gd").new()
var strike_left:=0.0
const STEALTH_ENTER_BLEND:=.38
const STEALTH_EXIT_BLEND:=.52
const STEALTH_FADE_OUT_SECONDS:=.48
const STEALTH_FADE_IN_SECONDS:=.52
var action_serial:=-1
var stealth_weight:=0.0
var alert: Label3D
var stealth_alpha:=1.0
var target_stealth_alpha:=1.0
var stealth_fade_from:=1.0
var stealth_fade_target:=1.0
var stealth_fade_elapsed:=0.0
var stealth_fade_duration:=STEALTH_FADE_IN_SECONDS
var last_alpha:=-1.0
var last_stealth_material_state:=-1
var solid_materials: Array[StandardMaterial3D]=[]
var fade_materials: Array[StandardMaterial3D]=[]
var stealth_surfaces: Array[Dictionary]=[]
var using_fade_materials:=false
var last_stealth_serial:=-1
var shadow_casters: Array[MeshInstance3D] = []
var shadow_material: StandardMaterial3D
var shadow_alpha:=1.0
var shadow_fade_from:=1.0
var shadow_fade_target:=1.0
var shadow_fade_elapsed:=0.0
var shadow_fade_duration:=STEALTH_FADE_IN_SECONDS
var stealth_material_warmup: Node3D
var haste_wind: Node3D
var vantage_wind: Node3D
var regen_effect: Node3D
var special_blend=preload("res://scripts/model_forge_pose_blend.gd").new()
var special_phase:=""
var dive_clock=preload("res://scripts/snapshot_animation_clock.gd").new()

func _init() -> void:
	asset_path="res://assets/characters/null.glb"
	class_title="Null"
	equipment=preload("res://scripts/null_equipment.gd").new()

func build(host: Node3D, team_color: Color) -> void:
	super.build(host,team_color)
	# Install after the original Idle has supplied the existing blade/finger grip.
	# The same portable library is installed for visible and compact pose-only rigs.
	clip_names.merge(Locomotion.install(player,skeleton),true)
	# Original forward run. LowForward now bakes the original StealthWalk with
	# its pelvis raised to match the hybrid directions and feet kept in place.
	clip_names["TravelForward"] = clip_names["Sprint"]
	# Keep both shader variants alive. Normal Null needs opaque depth rendering;
	# alpha=1 on a transparent material does not restore that rendering path.
	# Swapping retained variants also avoids repeatedly destroying/recreating the
	# transparency shader when the last fading Null becomes solid again.
	for i in materials.size():
		var material:=materials[i]
		material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a=1.0
		solid_materials.append(material)
		var fading: StandardMaterial3D=material.duplicate()
		fading.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		fade_materials.append(fading)
		var base: Color=base_colors[i]
		base.a=1.0
		base_colors[i]=base
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		# The visible mesh uses smooth alpha blending. Separate skinned shadow
		# instances use alpha hash so the real silhouette can also fade away.
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh.mesh.get_surface_count():
			var index:=materials.find(mesh.get_active_material(surface))
			if index>=0: stealth_surfaces.append({"mesh":mesh,"surface":surface,"index":index})
	if not pose_only: _build_model_shadow()
	strike_pose.build(skeleton)
	vantage_pose.build(skeleton)
	pose_blend.build(skeleton);special_blend.build(skeleton)
	if not pose_only:
		vantage_wind=load("res://scripts/null_vantage_wind.gd").new()
		vantage_wind.top_level=true
		host.add_child(vantage_wind)
		haste_wind=preload("res://scripts/null_haste_wind.gd").new()
		host.add_child(haste_wind)
		regen_effect=preload("res://scripts/null_regen_effect.gd").new()
		host.add_child(regen_effect)
		alert=Label3D.new();alert.text="!";alert.font_size=80;alert.outline_size=14
		alert.modulate=Color("f4e4bc");alert.pixel_size=.006
		alert.billboard=BaseMaterial3D.BILLBOARD_ENABLED;alert.position.y=2.1
		alert.visible=false;host.add_child(alert)

func animate(host: Node3D, delta: float, actor: CharacterBody3D) -> void:
	active_actor=actor
	if action_serial != int(actor.identity.get("null_action_serial",0)):
		var action: String=actor.identity.get("null_action","")
		if action_serial>=0 and action in ["stab","backstab"]:
			strike_pose.begin(action)
		action_serial=int(actor.identity.get("null_action_serial",0))
	var state: Dictionary=actor.identity.get("null_vantage",{})
	var wind_elapsed: float=state.get("elapsed",0.0)
	var next: String=state.get("phase","") if actor.hp>0 and actor.stunned<=0 else ""
	if next!=special_phase:
		# Capture the displayed pose, including a running/jumping entry or an
		# interrupted dive, and carry it into the next phase without a snap.
		special_blend.begin(.20 if next=="dive" else .16,.22 if next=="dive" else .18)
		special_phase=next;dive_clock.reset()
		if next.is_empty():transient_left=0.0
	locomotion.observe_motion(actor,last_position,initialized,delta)
	super.animate(host,delta,actor)
	strike_pose.apply(delta,actor.hp>0 and actor.stunned<=0 and next.is_empty())
	strike_left=strike_pose.remaining
	if actor.hp>0 and actor.stunned<=0:
		if not next.is_empty():
			var progress: float=dive_clock.advance(float(state.get("elapsed",0)),delta,actor.presentation_snapshot_serial,actor.motion_revision,2.0)
			wind_elapsed=progress
			var direction: Vector3=state.get("direction",Vector3(0,-1,-1).normalized())
			vantage_pose.apply(next,progress,direction)
			special_blend.apply(delta)
		equipment.apply()
	# Release special motion smoothly into the selected measured gait.
	if next.is_empty(): special_blend.apply(delta);equipment.apply()
	# Visibility is observer-local. Both the owner's half-opacity and an enemy's
	# full vanish take the same measured time, rather than the shorter alpha trip
	# ending halfway through the crouch.
	if not is_equal_approx(target_stealth_alpha,stealth_fade_target):
		stealth_fade_from=stealth_alpha
		stealth_fade_target=target_stealth_alpha
		stealth_fade_elapsed=0.0
		stealth_fade_duration=STEALTH_FADE_OUT_SECONDS if stealth_fade_target<stealth_fade_from else STEALTH_FADE_IN_SECONDS
	stealth_fade_elapsed=minf(stealth_fade_duration,stealth_fade_elapsed+maxf(0.0,delta))
	var fade_progress:=stealth_fade_elapsed/maxf(stealth_fade_duration,.001)
	stealth_alpha=lerpf(stealth_fade_from,stealth_fade_target,fade_progress*fade_progress*(3.0-2.0*fade_progress))
	_advance_shadow_fade(delta,Null.stealthed(actor))
	_apply_stealth_alpha()
	if vantage_wind!=null:
		vantage_wind.global_position=actor.global_position
		vantage_wind.conceal_alpha=stealth_alpha
		var motion_velocity: Vector3=actor.velocity if actor.presentation_velocity==null else actor.presentation_velocity
		var wind_speed:=float(state.get("dive_current_speed",motion_velocity.length())) if next=="dive" else motion_velocity.length()
		var wind_phase:=next if float(actor.identity.get("root",0.0))<=0.0 else ""
		vantage_wind.update_effect(wind_phase,wind_elapsed,state.get("direction",Vector3.UP),wind_speed,delta)
	if haste_wind!=null:
		haste_wind.update(actor,delta,filtered_speed,stealth_alpha)
	if regen_effect!=null:
		regen_effect.update(actor,delta,stealth_alpha)

func _advance_shadow_fade(delta: float, hidden: bool) -> void:
	# Everyone loses the entire shadow, even when they can still see Null's
	# half-opacity body. Detection/observer changes must not bring it back.
	var target:=0.0 if hidden else 1.0
	if not is_equal_approx(target,shadow_fade_target):
		shadow_fade_from=shadow_alpha
		shadow_fade_target=target
		shadow_fade_elapsed=0.0
		shadow_fade_duration=STEALTH_FADE_OUT_SECONDS if hidden else STEALTH_FADE_IN_SECONDS
	shadow_fade_elapsed=minf(shadow_fade_duration,shadow_fade_elapsed+maxf(0.0,delta))
	var progress:=shadow_fade_elapsed/shadow_fade_duration
	shadow_alpha=lerpf(shadow_fade_from,shadow_fade_target,progress*progress*(3.0-2.0*progress))

func _apply_stealth_alpha() -> void:
	model.visible=stealth_alpha>.01
	if shadow_material != null:
		shadow_material.albedo_color.a = shadow_alpha
	var fading:=stealth_alpha<1.0
	if fading!=using_fade_materials:
		using_fade_materials=fading
		for i in materials.size():
			var replacement:=fade_materials[i] if fading else solid_materials[i]
			replacement.albedo_color=materials[i].albedo_color
			replacement.emission=materials[i].emission
			replacement.emission_energy_multiplier=materials[i].emission_energy_multiplier
			materials[i]=replacement
		for binding in stealth_surfaces:
			binding.mesh.set_surface_override_material(binding.surface,materials[binding.index])
	# Damage/death tint changes can overwrite alpha even after the fade settled.
	if stealth_alpha==last_alpha and material_state==last_stealth_material_state: return
	last_alpha=stealth_alpha
	last_stealth_material_state=material_state
	for material in materials:
		material.albedo_color.a=stealth_alpha

func _build_model_shadow() -> void:
	shadow_material = StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	shadow_material.albedo_color = Color.WHITE
	# One retained material/shader from spawn through every stealth transition.
	# Alpha hash participates in the shadow map, unlike ordinary blended alpha.
	for source in model.find_children("*","MeshInstance3D",true,false):
		if source.mesh == null: continue
		var caster := MeshInstance3D.new()
		caster.name = "NullAnimatedShadow"
		caster.mesh = source.mesh
		caster.skin = source.skin
		caster.material_override = shadow_material
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		source.add_child(caster)
		caster.skeleton = caster.get_path_to(skeleton)
		shadow_casters.append(caster)

func prewarm_stealth_pipeline(host: Node3D) -> void:
	if pose_only or stealth_material_warmup!=null:
		return
	# The first transparent material submission otherwise makes the renderer
	# compile Null's alpha pipeline exactly when Stealth is pressed. Build hidden
	# instances after camera fading has configured these retained materials, so
	# the normal match setup pays that one-time cost instead of the first cast.
	stealth_material_warmup=Node3D.new()
	stealth_material_warmup.name="NullStealthMaterialWarmup"
	stealth_material_warmup.visible=false
	for binding in stealth_surfaces:
		var source: MeshInstance3D=binding.mesh
		var warmup:=MeshInstance3D.new()
		warmup.mesh=source.mesh
		warmup.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		warmup.set_surface_override_material(binding.surface,fade_materials[binding.index])
		stealth_material_warmup.add_child(warmup)
	host.add_child(stealth_material_warmup)

func override_clip(desired: String, alive: bool, stunned: bool, _delta: float) -> String:
	if not alive or stunned or active_actor==null:return desired
	if Null.busy(active_actor):
		return {"lift":"JumpStart","dive":"JumpLoop","recover":"JumpLand"}[active_actor.identity.null_vantage.phase]
	if Null.stealthed(active_actor) and not was_airborne:
		return locomotion.choose(filtered_speed,active_actor.walking,false,true)
	# Existing airborne/landing and special-action clips retain their precedence.
	if desired.begins_with("Jump"): return desired
	if desired == "Idle" or desired.begins_with("Cast") or is_locomotion(desired) or desired in ["Ready","LowIdle"]:
		return locomotion.choose(filtered_speed,active_actor.walking,preload("res://scripts/outlaw_mechanics.gd").severe_slowed(active_actor),false)
	return desired

func override_playback_rate(desired: String, default_rate: float) -> float:
	if desired=="TravelForward":return clampf(filtered_speed/4.4,.55,2.5)*RUN_CADENCE_SCALE
	if desired=="LowForward":return clampf(filtered_speed/2.8,.55,2.5)*1.6848
	if desired=="StealthWalk":return clampf(filtered_speed/2.8,.55,2.5)
	return Locomotion.playback_rate(desired,filtered_speed,default_rate)

func is_locomotion(name: String) -> bool:
	return Locomotion.is_locomotion(name) or name=="StealthWalk" or super.is_locomotion(name)

func transition_duration(previous: String, next: String) -> float:
	var previous_low := previous.begins_with("Stealth") or Locomotion.is_low(previous)
	var next_low := next.begins_with("Stealth") or Locomotion.is_low(next)
	if not previous_low and next_low:
		return STEALTH_ENTER_BLEND
	if previous_low and not next_low:
		return STEALTH_EXIT_BLEND
	if is_locomotion(previous) and is_locomotion(next): return .12
	return super.transition_duration(previous,next)

func visibility_for(actor, observer, reduced_effects: bool = false) -> void:
	if pose_only:return
	var hidden: bool=Null.stealthed(actor)
	var friendly: bool=observer==null or observer==actor or observer.team==actor.team
	if vantage_wind!=null:
		vantage_wind.set_observer_visible(not hidden or friendly)
		vantage_wind.set_reduced_effects(reduced_effects)
	if haste_wind!=null:
		# Haste trails are observer-local and disappear immediately for opponents;
		# they never linger through the character's gradual Stealth fade.
		haste_wind.set_observer_visible(not hidden or friendly)
	if regen_effect!=null:
		regen_effect.set_observer_visible(not hidden or friendly)
	var seen: bool=not hidden or friendly or Null.detected(actor,observer)
	target_stealth_alpha=.5 if hidden and seen else (0.0 if hidden else 1.0)
	var detected_by_any:=false
	for value in actor.identity.get("stealth_detection",{}).values():
		if float(value)>=Null.DETECT_SECONDS:detected_by_any=true;break
	alert.visible=hidden and seen and (detected_by_any if friendly else Null.detected(actor,observer))
