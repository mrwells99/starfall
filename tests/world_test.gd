extends SceneTree

# World mode: a persistent hangout on the arena map. No rounds, no timer, no
# victory, and no damage between people who have not agreed to fight.
var arena
var checks := 0
var fails := 0
func ck(c: bool, d: String) -> void:
	checks += 1
	if not c: fails += 1; push_error(d)
func _initialize() -> void: call_deferred("go")
func go() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.world_mode = true
	arena.mode = 1
	arena.roster = {1: {"champion": "Ember", "team": 0}, 2: {"champion": "Vanguard", "team": 1}}
	arena.begin_round()
	ck(arena.phase == "match", "World starts immediately with no countdown")
	ck(arena.countdown == 0.0, "No countdown in the world")
	ck(arena.actors.size() == 5, "Players and three stationary training dummies spawn")
	await physics_frame
	for center in arena.Layout.cover_centers():
		var query:=PhysicsRayQueryParameters3D.create(center+Vector3(-4,6,0),center+Vector3(4,6,0),1)
		ck(not arena.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Pillar extension blocks traversal and sight above the visible roof")
		var pose: Transform3D=arena.actors[1].transform
		pose.origin=center+Vector3(-4,6,0)
		ck(arena.actors[1].test_move(pose,Vector3.RIGHT*8),"The full movement capsule cannot cross onto a pillar from above")
	ck(arena.selected_id == -1, "World arrival does not auto-target players or dummies")
	arena.panel.hide()
	arena.update_visuals(0)
	ck(not arena.enemy_box.visible, "Arena frames are hidden in world mode")
	arena.edit_mode = true
	arena.update_visuals(0)
	ck(not arena.enemy_box.visible, "Edit previews do not enable arena frames in the world")
	arena.edit_mode = false
	arena.cycle_target()
	ck(arena.selected_id == 2, "World Tab prefers a player to challenge over training dummies")
	arena.actors[2].hp = 0
	arena.selected_id = -1
	for _step in arena.TrainingDummies.IDS:
		arena.cycle_target()
		ck(arena.selected_id == -1, "World Tab never selects dummies even when no players are available")
	arena.cycle_target(-1)
	ck(arena.selected_id == -1, "Reverse world targeting also skips all dummies")
	arena.actors[2].hp = 100
	arena.selected_id = -100
	arena.cycle_target()
	ck(arena.selected_id == 2, "Tab leaves a manually selected dummy for an available player")
	ck(arena.enemy_ids() == [2], "Arena target and focus shortcuts cannot pick a dummy either")
	var a = arena.actors[1]
	var b = arena.actors[2]
	var dummy = arena.actors[-100]
	ck(dummy.training_dummy, "Reserved world fixture is a training dummy")
	arena.damage(a, dummy, 10000)
	ck(dummy.hp == 1, "World dummy survives lethal damage at one HP without a duel")
	arena.damage(a, dummy, 10000)
	ck(dummy.hp == 1 and not arena.respawn_timers.has(-100), "Repeated damage cannot kill or respawn dummy")
	var origin: Vector3 = dummy.position
	arena.move_ability(dummy, Vector3(5, 0, 0))
	arena.tick_actor(dummy, 1.0)
	ck(dummy.position == origin and dummy.casting == -1, "Dummy stays stationary and does not fight")
	# Damage is refused until both agree.
	arena.damage(a, b, 30.0)
	ck(b.hp == 100, "You cannot harm someone who has not agreed to duel")
	arena.offer_duel(1, 2)
	ck(arena.duel_offers.get(2, -1) == 1, "A challenge is recorded against the target")
	arena.confirm_duel(2)
	ck(arena.duels.get(1, -1) == 2 and arena.duels.get(2, -1) == 1, "Accepting pairs both fighters")
	ck(arena.selected_id==2 and a.target_id==2 and b.target_id==1,"Duel acceptance immediately targets each opponent")
	arena.selected_id = -100
	ck(arena.selected_id==2,"A duel cannot change selection to a training dummy")
	arena.select_party(0)
	ck(arena.selected_id==2,"A duel cannot change selection to self through party targeting")
	arena.selected_id=-1
	ck(arena.selected_id==2,"A duel cannot clear its target")
	arena.apply_input(1,Vector2.ZERO,0,false,-100)
	ck(a.target_id==2 and arena.spell_target(a,0,-100)==2,"The authority pins movement and hostile action targets to the opponent")
	ck(arena.spell_target(a,5,2)==1,"Self-help abilities remain usable with the enemy locked")
	ck(not arena.may_harm(a,dummy),"Active duel attacks cannot damage a training dummy")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab.duplicate())
	await process_frame
	ck(arena.selected_id == 2 and not arena.social.typing(), "Real Tab input selects the duel opponent instead of focusing chat")
	tab.pressed = false
	Input.parse_input_event(tab.duplicate())
	for direction in [1, -1]:
		arena.cycle_target(direction)
		ck(arena.selected_id == 2, "Duel targeting stays on the opponent and skips dummies")
	arena.update_visuals(0)
	ck(not arena.enemy_box.visible and arena.target_frame.visible, "World duels use the target frame without arena frames")
	arena.social.entry.grab_focus()
	arena.selected_id = -1
	tab.pressed = true
	Input.parse_input_event(tab.duplicate())
	await process_frame
	ck(arena.selected_id == 2, "Chat typing preserves the locked duel opponent")
	tab.pressed = false
	Input.parse_input_event(tab.duplicate())
	arena.social.entry.release_focus()
	var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.physical_keycode=KEY_ESCAPE; escape.pressed=true
	arena._input(escape)
	ck(arena.panel.visible and arena.selected_id==2,"Escape opens the menu without clearing a locked opponent")
	arena.panel.hide()
	arena.damage(a, b, 30.0)
	ck(b.hp == 70, "Damage lands once a duel is agreed")
	# A third party still cannot join in.
	arena.roster[3] = {"champion": "Luminary", "team": 0}
	arena.admit_to_world()
	ck(arena.actors.size() == 6, "A latecomer is admitted without restarting the world")
	var c = null
	for x in arena.actors.values():
		if x.actor_id == 3: c = x
	arena.damage(c, b, 40.0)
	ck(b.hp == 70, "A bystander cannot interfere in someone else's duel")
	# Losing ends the duel and schedules a return rather than a defeat.
	arena.damage(a, b, 100.0)
	ck(b.hp == 0 and not arena.duels.has(1) and not arena.duels.has(2), "Losing ends the duel")
	ck(arena.respawn_timers.has(2), "The loser is queued to come back")
	arena.cycle_target()
	ck(arena.selected_id == 3, "After a duel Tab prefers the available bystander over dummies or a defeated player")
	arena.check_winner()
	ck(arena.phase == "match", "The world has no victory condition")
	arena.tick_world(4.0)
	ck(b.hp == 100 and not arena.respawn_timers.has(2), "The loser returns at full health")
	arena.world_mode = false
	arena.begin_round()
	ck(not arena.actors.has(-100), "Match arenas never spawn world dummies")
	ck(arena.selected_id==arena.locked_target_for(arena.local_id) and arena.selected_id!=-1,"A 1v1 arena automatically selects its opponent")
	var arena_opponent: int=arena.selected_id
	for candidate in [-1,arena.local_id,-100]:
		arena.selected_id=candidate
		ck(arena.selected_id==arena_opponent,"1v1 arena selection stays pinned")
	arena.mode=3
	arena.selected_id=arena.local_id
	ck(arena.selected_id==arena.local_id,"3v3 keeps normal free selection")
	arena.mode=1
	arena.dedicated = true
	arena.world_mode = true
	arena.begin_round()
	var server_dummy = arena.actors[-101]
	server_dummy.identity.entropy_dots[1] = {"left": 5.0, "tick": 0.0}
	arena.damage(arena.actors[1], server_dummy, 10000)
	arena.tick_actor(server_dummy, 2.0)
	ck(server_dummy.hp == 1, "Headless server applies direct damage and DoTs without killing dummy")
	ck(server_dummy.nameplate == null, "Server dummies require no rendering nodes")
	print("World checks: %d passed / %d total" % [checks - fails, checks])
	quit(1 if fails else 0)
