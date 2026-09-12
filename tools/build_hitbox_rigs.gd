extends SceneTree
## Offline extraction only. Dedicated servers load the resulting mesh-free rigs.
const NAMES := ["Ember", "Luminary", "Fulcrum", "Vanguard", "Outlaw", "Null"]
const OUT := "res://assets/hitboxes/"
func _initialize() -> void: call_deferred("run")

func prune(node: Node, rig: Skeleton3D, player: AnimationPlayer) -> void:
	for child in node.get_children():
		if child == rig or child == player or child.is_ancestor_of(rig) or child.is_ancestor_of(player):
			prune(child, rig, player)
		else:
			node.remove_child(child); child.free()

func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		own(child, scene)

func object_end(source: String, start: int) -> int:
	var depth:=0
	var quoted:=false
	var escaped:=false
	for i in range(start,source.length()):
		var c:=source[i]
		if quoted:
			if escaped: escaped=false
			elif c=="\\": escaped=true
			elif c=="\"": quoted=false
		elif c=="\"": quoted=true
		elif c=="{": depth+=1
		elif c=="}":
			depth-=1
			if depth==0:return i
	return -1

func replace_null_entry(source: String, entry: Dictionary) -> String:
	# Preserve every unrelated class's original numeric precision and formatting.
	var encoded:=JSON.stringify(entry,"\t").replace("\n","\n\t\t")
	var key:=source.find('"Null":')
	if key>=0:
		var start:=source.find("{",key)
		return source.left(start)+encoded+source.substr(object_end(source,start)+1)
	var classes:=source.find("{",source.find('"classes":'))
	assert(classes>=0)
	return source.left(classes+1)+'\n\t\t"Null": '+encoded+","+source.substr(classes+1)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var manifest := {"purpose": "Body hit detection only; no meshes, materials, textures or effects", "classes": {}}
	var original:=""
	if "--class=null" in OS.get_cmdline_user_args() and FileAccess.file_exists(OUT+"manifest.json"):
		original=FileAccess.get_file_as_string(OUT+"manifest.json")
	for title in NAMES:
		if "--class=null" in OS.get_cmdline_user_args() and title!="Null": continue
		var path: String = "res://assets/characters/" + title.to_lower() + ".glb"
		var scene: Node3D = load(path).instantiate(); root.add_child(scene)
		var rig: Skeleton3D
		var player: AnimationPlayer
		for node in scene.find_children("*", "Node", true, false):
			if node is Skeleton3D: rig = node
			if node is AnimationPlayer: player = node
		assert(rig != null and player != null)
		prune(scene, rig, player)
		var keys := 0
		for library_name in player.get_animation_library_list():
			var source_library := player.get_animation_library(library_name)
			var library := AnimationLibrary.new()
			for animation_name in source_library.get_animation_list():
				var animation: Animation = source_library.get_animation(animation_name).duplicate()
				for track in range(animation.get_track_count()-1, -1, -1):
					var target := animation.track_get_path(track)
					var bone := str(target.get_subname(0)) if target.get_subname_count() > 0 else ""
					if rig.find_bone(bone) < 0:
						animation.remove_track(track); continue
					# Constant tracks retain one exact value. No lossy resampling.
					var count := animation.track_get_key_count(track)
					var same := count > 1
					for key in range(1, count):
						if animation.track_get_key_value(track,key) != animation.track_get_key_value(track,0):
							same = false; break
					if same:
						for key in range(count-1,0,-1): animation.track_remove_key(track,key)
					keys += animation.track_get_key_count(track)
				library.add_animation(animation_name,animation)
			player.remove_animation_library(library_name); player.add_animation_library(library_name,library)
		own(scene,scene)
		# Godot 4.7 stores AnimationPlayer libraries as libraries/<name>, whereas
		# the deployed 4.5 engine expects one dictionary. Keep a version-neutral
		# reference table; runtime restores missing libraries on older engines.
		var portable_libraries := {}
		for library_name in player.get_animation_library_list(): portable_libraries[library_name] = player.get_animation_library(library_name)
		scene.set_meta("hitbox_libraries",portable_libraries)
		var packed := PackedScene.new(); assert(packed.pack(scene) == OK)
		var destination: String = OUT + title.to_lower() + "_rig.scn"
		assert(ResourceSaver.save(packed,destination,ResourceSaver.FLAG_COMPRESS) == OK)
		var bones := {}
		for i in rig.get_bone_count():
			if rig.get_bone_name(i).begins_with("DEF-") and not "f_" in rig.get_bone_name(i) and not "thumb" in rig.get_bone_name(i):
				var p := rig.global_transform * rig.get_bone_global_rest(i).origin
				bones[rig.get_bone_name(i)] = [p.x,p.y,p.z]
		manifest.classes[title] = {"source_sha256":FileAccess.get_sha256(path),"rig_sha256":FileAccess.get_sha256(destination),"bytes":FileAccess.get_file_as_bytes(destination).size(),"bones":rig.get_bone_count(),"keys":keys,"rest":bones}
		print(title, " hitbox rig: ", manifest.classes[title].bytes, " bytes, ", keys, " keys")
		scene.free()
	var output:=replace_null_entry(original,manifest.classes.Null) if not original.is_empty() else JSON.stringify(manifest,"\t")
	FileAccess.open(OUT+"manifest.json",FileAccess.WRITE).store_string(output)
	quit()
