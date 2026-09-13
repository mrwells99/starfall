extends SceneTree
## The approved B wind is cosmetic, observer-local, pooled, and absent on servers.
const Fighter = preload("res://scripts/combatant.gd")
const Wind = preload("res://scripts/null_vantage_wind.gd")
const STEP := 1.0 / 60.0
var checks := 0
var failures := 0
var next_id := 1
var gameplay_preserved := true

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		Engine.max_fps = 30
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_size(Vector2i(160, 100))
		DisplayServer.window_set_current_screen(0)
		DisplayServer.window_set_position(DisplayServer.screen_get_position(0) + Vector2i(40, 40))
	call_deferred("run")

func fighter(team: int = 0, presentation: bool = true):
	var actor = Fighter.new()
	root.add_child(actor)
	actor.setup(next_id, next_id, team, "Null", presentation)
	next_id += 1
	actor.presentation_grounded = true
	return actor

func gameplay(actor) -> Dictionary:
	var shape: CapsuleShape3D = actor.get_child(0).shape
	return {
		"snapshot": actor.snapshot().duplicate(true), "transform": actor.transform,
		"velocity": actor.velocity, "identity": actor.identity.duplicate(true),
		"charge": actor.charge.duplicate(true), "jump_queued": actor.jump_queued,
		"move_input": actor.move_input, "target_id": actor.target_id,
		"radius": shape.radius, "height": shape.height,
		"collision_layer": actor.collision_layer, "collision_mask": actor.collision_mask,
		"grounded": actor.presentation_grounded, "vertical": actor.presentation_vertical_speed,
		"presentation_velocity": actor.presentation_velocity,
		"snapshot_serial": actor.presentation_snapshot_serial,
	}

func animate(actor, delta: float = STEP) -> void:
	var before := gameplay(actor)
	if actor.champion_model != null:
		actor.champion_model.animate(delta, actor)
	else:
		actor.update_hitboxes(delta)
	gameplay_preserved = gameplay_preserved and before == gameplay(actor)

func phase(actor, value: String, elapsed: float = .2, speed: float = 35.0) -> void:
	var direction := Vector3(.3, -.7, -1).normalized()
	actor.identity.null_vantage = {} if value.is_empty() else {"phase": value, "elapsed": elapsed, "direction": direction, "target": 99, "power": 220.0}
	actor.velocity = Vector3.UP * speed if value == "lift" else direction * speed
	actor.presentation_velocity = actor.velocity
	actor.presentation_vertical_speed = actor.velocity.y
	actor.presentation_grounded = value in ["", "recover"]

func output_alpha(wind) -> float:
	var value := 0.0
	# The dummy renderer has no MultiMesh readback: its getters return white and
	# identity regardless of submitted data. Deterministic checks inspect retained
	# CPU pose/alpha state; native_readback separately checks submitted buffers
	# after drawing, since renderer interpolation does not advance synchronously.
	for alpha in wind._alphas:
		value = maxf(value, alpha * wind.conceal_alpha)
	return value

func transforms(wind) -> Array:
	return wind._poses.duplicate()

func resources(wind) -> Array:
	var values := [wind.get_instance_id()]
	for layer in wind.get_children():
		values.append(layer.get_instance_id())
		if layer is MultiMeshInstance3D:
			values.append(layer.multimesh.get_instance_id())
			values.append(layer.multimesh.mesh.get_instance_id())
			values.append(layer.material_override.get_instance_id())
	return values

func standalone() -> void:
	var wind := Wind.new()
	root.add_child(wind)
	check(wind.style == 1, "Live default is the approved B / Fast slipstream candidate")
	check(not wind.visible, "New wind is hidden before a Vantage cast")
	var ids := resources(wind)
	for name in ["lift", "dive", "recover"]:
		wind.clear()
		wind.update_effect(name, .10, Vector3(0, -.7, -1).normalized(), 45, STEP)
		var stats: Dictionary = wind.debug_stats()
		check(stats.phase == name and stats.visible and stats.max_alpha > .01, name + " creates visible airflow")
		check(stats.nodes == 3 and stats.pooled_wisps == 18 and stats.finite, name + " uses the retained finite 18-wisp pool")
		check(stats.max_extent < 7, name + " remains close to the character")
	wind.clear()
	wind.update_effect("dive", .31, Vector3.FORWARD, 4, STEP)
	var slow_extent: float = wind.debug_stats().max_extent
	var slow_alpha := output_alpha(wind)
	wind.clear()
	wind.update_effect("dive", .31, Vector3.FORWARD, 65, STEP)
	check(wind.debug_stats().max_extent > slow_extent * 1.5, "Faster dives stretch the B wake substantially farther")
	check(output_alpha(wind) > slow_alpha * 1.3, "Faster dives visibly strengthen the wind")
	wind.rotation = Vector3(.2, 1.7, -.3)
	var world_direction := Vector3(.5, -.5, -1).normalized()
	wind.clear()
	wind.update_effect("dive", .3, world_direction, 65, STEP)
	var wake_follows := true
	for transform: Transform3D in transforms(wind):
		var axis: Vector3 = (wind.global_basis * transform.basis.z).normalized()
		wake_follows = wake_follows and axis.dot(-world_direction) > .999
	check(wake_follows, "The wake trails world-space movement even under a rotated parent")
	for cast in 30:
		for name in ["lift", "dive", "recover"]:
			for frame in 6:
				wind.update_effect(name, frame * STEP, world_direction, 45, STEP)
		wind.clear()
	check(resources(wind) == ids, "Repeated casts retain the same nodes, meshes, material, and MultiMeshes")
	wind.update_effect("recover", .18, Vector3.FORWARD, 0, STEP)
	check(output_alpha(wind) < .001, "Recovery wind has faded completely at the ability's recovery endpoint")
	for invalid in ["", "cancelled", "unexpected"]:
		wind.update_effect("dive", .3, Vector3.FORWARD, 50, STEP)
		wind.update_effect(invalid, .3, Vector3.FORWARD, 50, STEP)
		check(not wind.visible and output_alpha(wind) == 0, invalid + " immediately clears the wind")
	wind.update_effect("dive", .3, Vector3.FORWARD, 50, STEP)
	wind.reset()
	check(not wind.visible and wind.debug_stats().phase.is_empty() and output_alpha(wind) == 0, "Explicit reset removes the complete previous wake")
	wind.free()

func presentation() -> void:
	var actor = fighter()
	var art = actor.champion_model.null_art
	var wind = art.vantage_wind
	check(wind != null and wind.get_parent() == actor.champion_model, "Visible Null creates the approved wind underneath its presentation host")
	check(wind.style == 1, "The real Null presenter uses B")
	actor.position = Vector3(4, 7, -8)
	actor.rotation.y = 1.3
	var ids := resources(wind)
	for name in ["lift", "dive", "recover"]:
		phase(actor, name, .1, 43)
		animate(actor)
		check(wind.debug_stats().phase == name and wind.visible, "Real presenter forwards the " + name + " phase")
	check(wind.top_level and wind.global_position.is_equal_approx(actor.global_position), "Airflow stays anchored at the actor's feet without inheriting pose tilt")
	phase(actor, "dive", .3, 15)
	actor.presentation_velocity = Vector3(0, -40, -30)
	animate(actor)
	check(is_equal_approx(wind._last_speed, 50), "Remote wind strength uses actual presentation velocity")
	actor.presentation_velocity = null
	animate(actor)
	check(is_equal_approx(wind._last_speed, 15), "Locally simulated wind falls back to actor velocity")
	actor.identity.null_vantage.dive_current_speed = 62.0
	animate(actor)
	check(is_equal_approx(wind._last_speed, 62), "A replicated accelerating dive uses its current speed rather than a stale velocity sample")
	actor.identity.null_vantage.erase("dive_current_speed")
	actor.presentation_snapshot_serial = 1
	for name in ["lift", "dive"]:
		var time_advances := true
		var transforms_change := true
		for frame in 24:
			if frame % 3 == 0:
				phase(actor, name, frame * STEP, 40)
				actor.presentation_snapshot_serial += 1
			var age: float = wind._phase_age
			var previous := transforms(wind)
			animate(actor)
			if frame > 3 and frame % 3 != 0:
				time_advances = time_advances and wind._phase_age > age
				transforms_change = transforms_change and transforms(wind) != previous
		check(time_advances, name + " wind time progresses between 20 Hz snapshots")
		check(transforms_change, name + " wind moves at presentation rate instead of freezing between packets")
	actor.presentation_snapshot_serial = 0
	for reason in ["death", "stun", "root", "cancel", "reset"]:
		actor.hp = 1500
		actor.stunned = 0
		actor.identity.root = 0
		phase(actor, "dive", .3, 45)
		animate(actor)
		check(wind.visible, reason + " starts from an active wind effect")
		match reason:
			"death": actor.hp = 0
			"stun": actor.stunned = .5
			"root": actor.identity.root = .5
			"cancel": actor.identity.null_vantage = {}
			"reset": actor.reset_identity()
		animate(actor)
		check(not wind.visible and output_alpha(wind) == 0, reason + " removes wind without waiting for a phase timer")
	check(resources(wind) == ids, "Full presentation and cancellation sequences never replace the wind's resources")
	var children: Array = wind.get_children()
	actor.free()
	var freed := not is_instance_valid(wind)
	for child in children:
		freed = freed and not is_instance_valid(child)
	check(freed, "Despawning Null frees the wind and every child without orphan nodes")

func visibility() -> void:
	var actor = fighter()
	var ally = fighter(0, false)
	var enemy = fighter(1, false)
	var art = actor.champion_model.null_art
	var wind = art.vantage_wind
	phase(actor, "dive", .3, 60)
	art.visibility_for(actor, actor)
	animate(actor)
	var opaque_alpha := output_alpha(wind)
	check(wind.visible and opaque_alpha > .1, "Normal unstealthed Null shows wind to its owner")
	actor.identity.stealth = true
	art.visibility_for(actor, enemy)
	check(not wind.visible, "Opponents lose active wind immediately when Null enters stealth")
	animate(actor, .01)
	check(not wind.visible and art.stealth_alpha > .95, "Enemy wind stays hidden while the body is still almost opaque early in the fade")
	actor.identity.stealth_detection = {enemy.actor_id: .7}
	art.visibility_for(actor, enemy)
	animate(actor, .25)
	check(not wind.visible, "A detecting opponent never sees a stealthed Null's wind")
	for observer in [actor, ally]:
		actor.identity.stealth = false
		art.visibility_for(actor, observer)
		animate(actor, .6)
		var full_alpha := output_alpha(wind)
		actor.identity.stealth = true
		art.visibility_for(actor, observer)
		animate(actor, .24)
		var middle_alpha := output_alpha(wind)
		check(wind.visible and middle_alpha < full_alpha * .9 and middle_alpha > full_alpha * .6, "Friendly wind follows the body halfway through its smooth stealth fade")
		animate(actor, .24)
		check(wind.visible and absf(output_alpha(wind) / full_alpha - .5) < .03, "Owner and ally retain only half-opacity wind after stealth settles")
	actor.identity.stealth = false
	art.visibility_for(actor, enemy)
	animate(actor, .26)
	check(wind.visible and art.stealth_alpha > .5 and art.stealth_alpha < 1, "Wind returns with the smooth body reveal after leaving stealth")
	animate(actor, .26)
	check(is_equal_approx(art.stealth_alpha, 1.0) and absf(output_alpha(wind) - opaque_alpha) < .015, "Unstealth restores full-strength wind with no leftover transparency")
	art.visibility_for(actor, actor, true)
	check(not wind.visible, "Reduced-effects setting hides an already active effect immediately")
	animate(actor)
	check(not wind.visible, "Reduced-effects remains respected on subsequent animation frames")
	art.visibility_for(actor, actor, false)
	animate(actor)
	check(wind.visible and output_alpha(wind) > .1, "Turning reduced-effects off resumes the current phase")
	actor.free()
	ally.free()
	enemy.free()

func isolation() -> void:
	var a = fighter()
	var b = fighter(1)
	phase(a, "dive", .3, 50)
	phase(b, "dive", .3, 50)
	var art_a = a.champion_model.null_art
	var art_b = b.champion_model.null_art
	var wind_a = art_a.vantage_wind
	var wind_b = art_b.vantage_wind
	art_a.visibility_for(a, a)
	art_b.visibility_for(b, b)
	animate(a)
	animate(b)
	var b_alpha := output_alpha(wind_b)
	var b_transforms := transforms(wind_b)
	a.identity.stealth = true
	art_a.visibility_for(a, a)
	animate(a, .6)
	check(absf(output_alpha(wind_a) - b_alpha * .5) < .02, "Only the fading actor's individual ribbon colors are reduced")
	check(output_alpha(wind_b) == b_alpha and transforms(wind_b) == b_transforms and wind_b.visible, "One Null's visibility changes do not alter another Null's wind")
	check(Wind.air_material.albedo_color.a == 1.0, "Shared airflow material remains opaque so actors cannot leak alpha state")
	for layer in wind_a.get_children():
		if layer is MultiMeshInstance3D:
			check(layer.multimesh != wind_b.get_child(layer.get_index()).multimesh, "Concurrent characters have independent per-instance wind buffers")
	art_a.visibility_for(a, b)
	check(not wind_a.visible and wind_b.visible, "Hiding an enemy's stealth wake does not hide the observer's own wake")
	a.free()
	b.free()
	var compact = fighter(0, false)
	compact.setup_hitboxes()
	check(compact.champion_model == null and compact.hitbox_pose.art.pose_only, "Dedicated fixture uses the actual compact pose-only rig")
	check(compact.hitbox_pose.art.vantage_wind == null, "Pose-only server rigs never instantiate wind")
	for name in ["lift", "dive", "recover", ""]:
		phase(compact, name, .1, 40)
		animate(compact)
	check(compact.find_children("*", "MultiMeshInstance3D", true, false).is_empty(), "All dedicated Vantage phases remain free of wind render nodes")
	compact.free()
	for path in ["res://scripts/null_vantage_wind.gd", "res://scripts/null_art.gd"]:
		var source := FileAccess.get_file_as_string(path)
		check(not source.contains("res://artifacts/") and not source.contains("res://local_resources/"), path + " has no dependency on local-only preview/cache assets")

func native_readback() -> void:
	var actor = fighter()
	var enemy = fighter(1, false)
	var art = actor.champion_model.null_art
	var wind = art.vantage_wind
	for state in ["lift", "dive", "recover", "owner_stealth", "enemy_stealth", "reveal", "cancel"]:
		actor.identity.stealth = state in ["owner_stealth", "enemy_stealth"]
		phase(actor, state if state in ["lift", "dive", "recover"] else ("" if state == "cancel" else "dive"), .1 if state == "recover" else .3, 55)
		art.visibility_for(actor, enemy if state == "enemy_stealth" else actor)
		animate(actor, .6)
		# A static submitted sample must be allowed to cross render/physics frame
		# boundaries before comparing its renderer-owned interpolation buffers.
		for frame in 3:
			await RenderingServer.frame_post_draw
		var colors_match := true
		var poses_match := true
		for index in Wind.RIBBON_COUNT:
			var layer = wind._layers[index / Wind.PER_LAYER]
			var slot := index % Wind.PER_LAYER
			var submitted_color: Color = layer.multimesh.get_instance_color(slot)
			var submitted_pose: Transform3D = layer.multimesh.get_instance_transform(slot)
			var expected_alpha: float = wind._alphas[index] * wind.conceal_alpha
			colors_match = colors_match and absf(submitted_color.a - expected_alpha) < .005
			poses_match = poses_match and submitted_pose.is_equal_approx(wind._poses[index])
		check(colors_match, state + " native MultiMesh colors match the intended per-actor faded alpha")
		check(poses_match, state + " native MultiMesh transforms match the intended flowing wind poses")
	actor.free()
	enemy.free()

func run() -> void:
	standalone()
	presentation()
	visibility()
	isolation()
	check(gameplay_preserved, "Wind presentation never modifies gameplay snapshots, movement, collision, resources, health, or cooldowns")
	print("Wind inspection: retained CPU transforms/alpha")
	if DisplayServer.get_name() != "headless":
		await native_readback()
		print("Additional native checks: MultiMesh transform/color readback after render frames")
	print("Null Vantage wind checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
