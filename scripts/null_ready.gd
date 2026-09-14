extends RefCounted
## Owner-selected K+ ordinary idle; shared timing/binding for each class's carrying variant.
const LIBRARY=preload("res://assets/animations/null_ready.res")
const NAME:="null_ready"
const PLAYBACK_SCALE:=1.15 # Additional owner-requested speed over the selected K+ bake.
static var remapped_libraries:Dictionary={}

static func install(player:AnimationPlayer,skeleton:Skeleton3D,source:AnimationLibrary=LIBRARY)->String:
	var active:=String(player.assigned_animation)
	var time:=player.current_animation_position if not active.is_empty() else 0.0
	var playing:=player.is_playing()
	var path:=String(player.get_node(player.root_node).get_path_to(skeleton))
	var cache_key:=source.resource_path+":"+path
	var library_name:=NAME if source==LIBRARY else "shared_ready"
	if not remapped_libraries.has(cache_key):
		var library:=AnimationLibrary.new()
		var clip:Animation=source.get_animation("Ready").duplicate(false)
		for track in clip.get_track_count():
			var bone:=String(clip.track_get_path(track).get_subname(0))
			assert(skeleton.find_bone(bone)>=0,"Approved idle requires bone "+bone)
			clip.track_set_path(track,NodePath(path+":"+bone))
			for key in clip.track_get_key_count(track):
				clip.track_set_key_time(track,key,clip.track_get_key_time(track,key)/PLAYBACK_SCALE)
		clip.length/=PLAYBACK_SCALE
		var added:=library.add_animation("Ready",clip)
		assert(added==OK)
		remapped_libraries[cache_key]=library
	if not player.has_animation_library(library_name):
		var installed:=player.add_animation_library(library_name,remapped_libraries[cache_key])
		assert(installed==OK)
		# Preserve active playback, including Godot 4.5's library-restoration requirement.
		if not active.is_empty():
			player.play(active,0.0);player.seek(time,true);player.advance(0.0)
			if not playing:player.pause()
	return library_name+"/Ready"

static func phases(original:Dictionary,source:AnimationLibrary=LIBRARY)->Dictionary:
	# Keep shared movement and other state metadata immutable.
	var result:=original.duplicate(false)
	var clips:Dictionary=original.clips.duplicate(false)
	var ready:Dictionary=source.get_meta("ready_features").duplicate(true)
	for sample in ready.samples:
		sample.time/=PLAYBACK_SCALE
		for side in sample.foot_velocity.size():sample.foot_velocity[side]*=PLAYBACK_SCALE
	for field in ["length","duration"]:
		if ready.has(field):ready[field]/=PLAYBACK_SCALE
	clips.Ready=ready
	result.clips=clips
	return result
