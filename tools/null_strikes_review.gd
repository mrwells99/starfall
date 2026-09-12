extends "res://tools/null_review.gd"
const OUTPUT := "res://artifacts/null-strikes-v3/"

func run() -> void:
	super.run()
	ready=false
	picker.get_parent().hide()
	var caption:=Label.new()
	caption.position=Vector2(30,30)
	caption.add_theme_font_size_override("font_size",28)
	stage.get_children().filter(func(n):return n is CanvasLayer)[0].add_child(caption)
	var sheet:=Image.create(1750,630,false,Image.FORMAT_RGB8)
	for row in 2:
		var action_name: String="stab" if row==0 else "backstab"
		var times: Array=[.07,.14,.23,.33,.44] if row==0 else [.09,.19,.30,.44,.60]
		for column in times.size():
			select_class("Null")
			set_view("Three-quarter")
			if "--side" in OS.get_cmdline_user_args():set_view("Side")
			for frame in 30: actor.champion_model.animate(1.0/60,actor)
			actor.identity.null_action=action_name;actor.identity.null_action_serial+=1
			for frame in roundi(times[column]*60): actor.champion_model.animate(1.0/60,actor)
			caption.text=("TEMPORAL STRIKE" if row==0 else "BACKSTAB")+"  %.2fs" % times[column]
			await RenderingServer.frame_post_draw
			var picture:=root.get_texture().get_image()
			picture.save_png(OUTPUT+action_name+"-%d.png" % column)
			picture.resize(350,315,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(picture,Rect2i(0,0,350,315),Vector2i(column*350,row*315))
	sheet.save_png(OUTPUT+("side-sheet.png" if "--side" in OS.get_cmdline_user_args() else "attack-sheet.png"))
	print("NULL_STRIKES_REVIEW_CAPTURED")
	stage.queue_free()
	await process_frame
	quit()
