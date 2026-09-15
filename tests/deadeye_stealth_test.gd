extends SceneTree
var checks := 0
var failures := 0
func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game); game.set_physics_process(false); game.set_process(false)
	game.roster={1:{"champion":"Null","team":0},2:{"champion":"Outlaw","team":1},3:{"champion":"Ember","team":1}}
	game.begin_round(); game.phase="match"
	var n=game.actors[1]; var o=game.actors[2]; var other=game.actors[3]
	n.position=Vector3(0,.025,-8);o.position=Vector3(0,.025,0);other.position=Vector3(0,.025,1)
	game.Null.enter(game,n)
	ck(not game.Null.targetable(game,o,n),"Hidden before Deadeye")
	var slot := -1
	for i in o.kit.size():
		if o.kit[i].kind=="deadeye": slot=i
	o.casting=slot;o.cast_left=3
	game.Outlaw.begin_channel(game,o,o.kit[slot],o.actor_id)
	game.Null.tick(game,n,.016)
	ck(game.Null.stealthed(n) and game.Null.detected(n,o),"Deadeye detects without breaking Stealth")
	ck(game.Null.targetable(game,o,n),"Null is targetable by the casting Outlaw")
	ck(not game.Null.targetable(game,other,n),"Detection is not shared with Outlaw's teammate")
	var art=n.champion_model.null_art
	art.visibility_for(n,o)
	ck(art.target_stealth_alpha==.5 and art.alert.visible,"Outlaw sees existing half-opacity detection and exclamation")
	art.visibility_for(n,n)
	ck(art.alert.visible,"Null receives the same detection warning")
	o.casting=-1;game.Outlaw.refund_interrupted_channel(game,o);game.Null.tick(game,n,.016)
	art.visibility_for(n,n)
	ck(not game.Null.detected(n,o) and not art.alert.visible,"Cancelled Deadeye removes distant detection and warning")
	o.casting=slot;o.cast_left=3;game.Outlaw.begin_channel(game,o,o.kit[slot],o.actor_id)
	game.Null.break_stealth(game,n);game.Null.enter(game,n)
	ck(game.Null.detected(n,o) and n.identity.stealth_detection.has(o.actor_id),"Stealth entered during Deadeye is detected immediately")
	await physics_frame
	var before:float=n.hp
	game.Outlaw.tick_channel(game,o,3.01)
	ck(n.hp==before-n.BASE_MAX_HEALTH*.4*n.DAMAGE_SCALE,"Deadeye hits concealed Null within range and clear LOS")
	game.free()
	print("Deadeye stealth checks: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures==0 else 1)
