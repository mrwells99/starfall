extends SceneTree
## Read-only policy audit. No imports, exports, downloads, or gameplay changes.
const TARGETS: Array[String] = [
	"addons/netfox/",
	"addons/netfox.internals/",
	"addons/Color grading/",
	"Compositor/Color grading/",
	"Compositor/General/",
	"addons/ezcha_network/",
	"addons/limboai/",
	"demo/",
	"addons/ballistic_solutions/",
	"addons/real_equation_solver/",
	"addons/BallisticSolutions.Godot/",
	"Unarmed/",
	"local_resources/",
	"Unarmed.glb",
	"Unarmed.glb.import",
	"Unarmed_RM.glb",
	"Unarmed_RM.glb.import",
	"RPG-Character-Bones.FBX",
	"RPG-Character-Bones.FBX.import",
	"RPG-Character.psd",
	"RPG Animations GLB FREE Version Changes.txt",
	"explosive_anim_importer v4.2.py",
	"explosive_anim_importer v5.0.py",
	"explosive.ws-products-rpg-animations-glb.url",
	"explosive.ws-to-godot.url"
]
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var git_rules := FileAccess.get_file_as_string("res://.gitignore").split("\n")
	var docker_rules := FileAccess.get_file_as_string("res://.dockerignore").split("\n")
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "Export presets load")
	var git_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var checked_files := 0
	var preset_count := 0
	for section in presets.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"): continue
		preset_count += 1
	check(preset_count == 2, "Both current desktop export presets are covered")
	for target in TARGETS:
		check(has_rule(git_rules, "/" + target), "Git rule: " + target)
		check(has_rule(docker_rules, target), "Docker rule: " + target)
		var tracked: Array = []
		var tracked_code := OS.execute("git", ["-c", "safe.directory=" + git_root, "-C", git_root, "ls-files", "--", target], tracked, true)
		check(tracked_code == 0 and "".join(tracked).strip_edges().is_empty(), "No tracked reference files: " + target)
		check(OS.execute("git", ["-c", "safe.directory=" + git_root, "-C", git_root, "check-ignore", "--quiet", "--", target]) == 0, "Git actually ignores: " + target)
		var candidates: Array[String] = []
		if target.ends_with("/"):
			collect(target.trim_suffix("/"), candidates)
		else:
			check(FileAccess.file_exists("res://" + target), "Source still exists: " + target)
			candidates.append(target)
		checked_files += candidates.size()
		for section in presets.get_sections():
			if not section.begins_with("preset.") or section.ends_with(".options"): continue
			var filters := str(presets.get_value(section, "exclude_filter", "")).split(",")
			var expected := target + "*" if target.ends_with("/") else target
			check(filters.has(expected), "Export rule in " + section + ": " + target)
			for candidate in candidates:
				var excluded := false
				for pattern in filters:
					if candidate.matchn(pattern.strip_edges()): excluded = true; break
				check(excluded, "Export must exclude " + candidate)
	check(FileAccess.file_exists("res://local_resources/.gdignore"), "Cache is not automatically imported")
	check(not has_rule(git_rules, "/addons/") and not has_rule(docker_rules, "addons/"), "Unrelated addons are not blanket-excluded")
	print("Local resource policy: %d passed / %d total; %d retained local files checked" % [checks - failures, checks, checked_files])
	quit(0 if failures == 0 else 1)

func has_rule(lines: PackedStringArray, value: String) -> bool:
	for line in lines:
		if line.strip_edges() == value: return true
	return false

func collect(folder: String, result: Array[String]) -> void:
	var directory := DirAccess.open("res://" + folder)
	check(directory != null, "Source folder still exists: " + folder)
	if directory == null: return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var path := folder.path_join(name)
			if directory.current_is_dir(): collect(path, result)
			else: result.append(path)
		name = directory.get_next()
	directory.list_dir_end()
