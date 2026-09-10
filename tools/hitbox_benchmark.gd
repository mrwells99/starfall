extends SceneTree
## Same six moving actors and cooldown presses, baseline versus fitted hitscan.
var game
var frames := 0
var rows := []
var fitted := true
var requests := 0
var resolved := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	fitted = not "--without-hitboxes" in OS.get_cmdline_user_args()
	game = load("res://arena.tscn").instantiate()
	game.set_script(load("res://tools/hitbox_benchmark_arena.gd"))
	game.hitboxes_enabled = fitted
	root.add_child(game); game.set_physics_process(false)
	game.mode = 3
	game.roster = {}
	for i in 6: game.roster[i+10] = {"champion":["Outlaw","Ember","Vanguard","Fulcrum","Luminary","Outlaw"][i],"team":i/3}
	game.begin_round(); game.phase = "match"
	for actor in game.actors.values():
		actor.owner_peer = 0
		actor.kit[0] = game.Kits.spell("Benchmark cooldown","damage",12,18,0,.5)
		if fitted: actor.kit[0].aim_mode = "hitscan"
		actor.position = Vector3(float((actor.actor_id-1)%3-1)*2, .025, 4 if actor.team == 0 else -4)
	game.aimed_shot_resolved.connect(func(_result): resolved += 1)
	physics_frame.connect(tick)

func tick() -> void:
	var started := Time.get_ticks_usec()
	for actor in game.actors.values():
		actor.hp = 100; actor.input_age = 0
		actor.move_input = Vector2(sin(frames*.025)*.35,0)
		var target
		for other in game.actors.values():
			if other.team != actor.team: target = other; break
		var offset: Vector3 = target.position-actor.position
		actor.rotation.y = atan2(-offset.x,-offset.z)
		if frames > 120 and frames%30 == 0:
			requests += 1
			if fitted:
				var origin: Vector3 = game.aimed_combat.firing_origin(actor.body_hitboxes.points)
				var end: Vector3 = game.aimed_combat.firing_origin(target.body_hitboxes.points)
				game.aimed_combat.enqueue(game,actor.actor_id,0,frames,0,(end-origin).normalized(),game.aimed_combat.clock,actor.motion_revision)
			else:
				if game.try_spell(actor.actor_id,0,target.actor_id): resolved += 1
	game._physics_process(1.0/60)
	var micros := Time.get_ticks_usec()-started
	if frames >= 120: rows.append([frames-120,micros,game.aimed_combat.sample_usec if fitted else 0,OS.get_static_memory_usage()])
	frames += 1
	if frames < 720: return
	var label := "fitted" if fitted else "baseline"
	var path := "res://artifacts/aimed-combat/"+label+"-ticks.csv"
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_csv_line(["tick","simulation_usec","hitbox_update_usec","godot_static_bytes"])
	var values := []
	for row in rows:
		file.store_csv_line(PackedStringArray(row.map(func(value): return str(value)))); values.append(row[1])
	values.sort()
	var total := 0.0
	for value in values: total += value
	var summary := {"mode":label,"ticks":rows.size(),"mean_ms":total/values.size()/1000,"p95_ms":values[int(values.size()*.95)]/1000.0,"p99_ms":values[int(values.size()*.99)]/1000.0,"worst_ms":values.back()/1000.0,"static_bytes":OS.get_static_memory_usage(),"requests":requests,"resolved":resolved,"godot":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"os":OS.get_name()}
	FileAccess.open("res://artifacts/aimed-combat/"+label+"-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(summary,"\t"))
	print("HITBOX_BENCHMARK ",JSON.stringify(summary))
	quit()
