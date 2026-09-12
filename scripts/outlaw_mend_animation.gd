extends RefCounted
## Explicit installation works with both desktop and dedicated-server libraries.
const LIBRARY = preload("res://assets/animations/outlaw_mend.tres")

static func install(player: AnimationPlayer, skeleton: Skeleton3D) -> String:
	var animation: Animation = LIBRARY.get_animation("Mend").duplicate(true)
	var path := String(player.get_node(player.root_node).get_path_to(skeleton))
	for track in animation.get_track_count():
		var bone := String(animation.track_get_path(track).get_subname(0))
		assert(skeleton.find_bone(bone) >= 0,"Mend requires source bone "+bone)
		animation.track_set_path(track,NodePath(path+":"+bone))
	var library := AnimationLibrary.new()
	library.add_animation("Mend",animation)
	assert(player.add_animation_library("mend_handwork",library) == OK)
	return "mend_handwork/Mend"
