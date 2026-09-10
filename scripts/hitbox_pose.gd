extends Node3D
## Same accepted animator, using an offline-extracted rig with zero render resources.
var torso: MeshInstance3D
var art
const SCRIPTS := {"Ember":"ember_art", "Luminary":"luminary_art", "Fulcrum":"fulcrum_art", "Vanguard":"vanguard_authored", "Outlaw":"outlaw_art"}

func build(title: String) -> void:
	name = "ServerHitboxPose"
	art = load("res://scripts/"+SCRIPTS[title]+".gd").new()
	art.asset = preload("res://scripts/character_asset_cache.gd").get_scene("res://assets/hitboxes/"+title.to_lower()+"_rig.scn")
	art.pose_only = true
	art.build(self,Color.WHITE)

func animate(delta: float, actor) -> void:
	art.animate(self,delta,actor)
