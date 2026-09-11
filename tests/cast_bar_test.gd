extends SceneTree
var game
var actor
var checks := 0
var failures := 0

class MemoryConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)

func paint_and_check(expected: Color, message: String, interrupted: bool = false) -> void:
	for frame in [game.player_frame,game.target_frame,game.focus_frame]:
		game.update_frame(frame,actor.actor_id,"")
		var cast: ProgressBar=frame.get_child(2)
		check(cast.visible and cast.get_theme_stylebox("fill").bg_color==expected, message+" on "+str(frame.name))
	for row in [game.party_buttons[1],game.enemy_buttons[0]]:
		game.paint_roster_row(row,actor,"",row==game.party_buttons[1])
		var cast: ProgressBar=row.get_node("Details").cast
		var color:=expected
		if expected==Color("8b713e"):color=Color("675183")
		check(cast.visible and cast.get_theme_stylebox("fill").bg_color==color,message+" on roster row")
	if interrupted:
		check(game.player_frame.get_child(2).get_child(0).text=="INTERRUPTED","Interrupted feedback retains its label")

func run() -> void:
	root.disable_3d=true
	if "--capture" in OS.get_cmdline_user_args():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_current_screen(0)
		DisplayServer.window_set_size(Vector2i(1280,800))
		DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(40,50))
	game=preload("res://tests/ui_test_arena.gd").new()
	game.config=MemoryConfig.new();root.add_child(game)
	await process_frame;await process_frame
	game.set_physics_process(false);game.set_process(false)
	game.champion_choice.select(4);game.mode_choice.select(1);game.local_match();game.phase="match"
	actor=game.actors[game.local_id]
	game.update_visuals(0)
	for champion in game.Kits.NAMES:
		actor.champion=champion;actor.kit=game.Kits.get_kit(champion)
		for slot in actor.kit.size():
			var spell: Dictionary=actor.kit[slot]
			if spell.cast<=0:continue
			actor.casting=slot;actor.cast_left=spell.cast*.5
			var immune: bool=champion=="Outlaw" and spell.kind in ["severe","starshot","deadeye","lasso"]
			check(game.kick_immune(actor)==immune,"Combat immunity for "+champion+" "+spell.name)
			paint_and_check(Color("808080") if immune else Color("8b713e"),champion+" "+spell.name)
	actor.champion="Outlaw";actor.kit=game.Kits.get_kit("Outlaw");actor.casting=5;actor.cast_left=1
	actor.identity.backflip_active=true;actor.velocity.y=2
	paint_and_check(Color("808080"),"Temporary airborne kick immunity")
	actor.identity.backflip_active=false;actor.velocity.y=0
	paint_and_check(Color("8b713e"),"Ordinary color returns after immunity ends")
	actor.casting=1;actor.cast_left=.3
	paint_and_check(Color("808080"),"Severe changes back to gray")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/outlaw-forge-v2/unkickable-cast-bars.png")
	game.combat_text.interrupts[actor.actor_id]=Time.get_ticks_msec()+1000
	paint_and_check(Color("854657"),"Interrupted feedback retains its color",true)
	game.combat_text.interrupts.clear();actor.casting=-1
	game.update_frame(game.player_frame,actor.actor_id,"")
	game.party_buttons[1].get_node("Details").sync(actor)
	check(not game.player_frame.get_child(2).visible and not game.party_buttons[1].get_node("Details").cast.visible,"Finished casts hide all cast strips")
	game.queue_free();await process_frame;await process_frame
	print("Cast bar checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
