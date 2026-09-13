extends RefCounted
## Reuse the selected Null idle body, with baked native carrying chains and garments.
const Ready=preload("res://scripts/null_ready.gd")
const PATHS={
	"Ember":"res://assets/animations/ember_ready.res",
	"Luminary":"res://assets/animations/luminary_ready.res",
	"Fulcrum":"res://assets/animations/fulcrum_ready.res",
	"Vanguard":"res://assets/animations/vanguard_ready.res",
	"Outlaw":"res://assets/animations/outlaw_ready.res"
}

static func apply(art,title:String,features:Dictionary)->Dictionary:
	var source:AnimationLibrary=load(PATHS[title])
	art.clip_names.Ready=Ready.install(art.player,art.skeleton,source)
	return Ready.phases(features,source)
