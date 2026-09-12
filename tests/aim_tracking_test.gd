extends SceneTree
const Fixture = preload("res://tests/hitbox_roster_test.gd")
const Aimed = preload("res://scripts/aimed_combat.gd")
const Policy = preload("res://scripts/aim_tracking.gd")
const Kits = preload("res://scripts/kits.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func fighter(id: int):
	var a := Fixture.Actor.new()
	a.actor_id = id; a.owner_peer = id; a.champion = "Outlaw"; a.kit = Kits.get_kit("Outlaw")
	return a
func _initialize() -> void:
	var game := Fixture.Game.new()
	var aimed := Aimed.new(); game.aimed_combat = aimed
	var p = aimed.tracking
	var a = fighter(2); var b = fighter(3)
	game.actors = {2:a,3:b}
	check(not p.required(game),"Low-ping idle aiming classes do not continuously track")
	check(not p.set_mode(game,2,3,1,true),"Peer cannot activate another player's aim")
	check(not p.set_mode(game,2,2,0,true),"Invalid mode sequence is rejected")
	check(p.set_mode(game,2,2,1,true) and p.required(game),"Aim-on immediately enables server tracking")
	check(not p.ready(game,2),"Entering aim does not pre-charge the trigger")
	check(p.begin_charge(game,2,2,1),"Trigger starts authoritative charge")
	aimed.clock = .3
	check(not p.ready(game,2),"An early fire cannot skip charge")
	check(p.begin_charge(game,2,2,1) and p.modes[2].charge_since == 0,"Duplicate trigger does not restart charge")
	aimed.clock = .6
	check(p.ready(game,2),"Charged trigger is ready after .6 seconds")
	p.consume_charge(2)
	check(not p.ready(game,2),"One charge cannot authorize two separate bursts")
	check(p.set_mode(game,3,3,1,true),"Second player may aim concurrently")
	check(p.set_mode(game,2,2,2,false) and p.required(game),"One player's exit cannot stop another player's tracking")
	check(not p.set_mode(game,2,2,1,true) and not p.active(2),"Stale aim-on cannot undo a newer exit")
	p.set_mode(game,3,3,2,false)
	check(not p.required(game),"Last aim exit releases tracking")
	game.outlaw_detonation.bursts[2] = {}
	check(p.required(game),"An in-flight burst retains history until resolved or canceled")
	game.outlaw_detonation.bursts.clear()
	p.set_mode(game,2,2,3,true); p.begin_charge(game,2,2,3)
	a.motion_revision += 1
	check(not p.ready(game,2) and not p.begin_charge(game,2,2,3),"Teleport revision invalidates old charge immediately")
	p.tick(game,.016)
	check(not p.active(2),"Revision change removes aim lifetime")
	p.set_mode(game,2,2,4,true); a.owner_peer = 9; p.tick(game,.016)
	check(not p.active(2),"Disconnect/ownership transfer clears stale aim state")
	check(p.set_mode(game,2,9,1,true),"Reconnected owner can start a fresh sequence")
	a.hp = 0; p.tick(game,.016)
	check(not p.active(2),"Death cancels aim/charge")
	a.hp = 1500
	for blocked in ["stun","cast","roll","backflip"]:
		if blocked == "stun": a.stunned = 1
		if blocked == "cast": a.casting = 0
		if blocked == "roll": a.identity.roll_left = 1
		if blocked == "backflip": a.identity.backflip_active = true
		check(not p.set_mode(game,2,9,2,true),"Cannot enter aim during "+blocked)
		a.stunned = 0; a.casting = -1; a.identity.roll_left = 0; a.identity.backflip_active = false
	p.reset()
	for i in 12: p.observe_ping(9,100)
	p.observe_ping(9,900)
	check(not p.high_ping(),"One large ping spike does not force continuous tracking")
	for i in 24: p.observe_ping(9,100)
	check(not p.high_ping(),"Recovery from a spike stays aim-only")
	p.reset()
	for i in 40: p.observe_ping(9,160)
	check(not p.high_ping(),"Exactly 160 ms is not over the threshold")
	for i in 40: p.observe_ping(9,150 if i%2 == 0 else 170)
	check(not p.high_ping(),"Oscillation across the threshold is not sustained high ping")
	p.reset()
	for i in 7: p.observe_ping(9,180)
	check(not p.high_ping(),"Less than two seconds high is not sustained")
	p.observe_ping(9,180)
	check(p.high_ping() and p.required(game),"Two seconds steadily above 160 enables continuous tracking")
	for i in 40: p.observe_ping(9,150)
	check(p.high_ping(),"Recovery band prevents mode flicker around 160")
	for i in 4: p.observe_ping(9,100)
	check(p.high_ping(),"A brief good ping reading does not clear fallback")
	for i in 40: p.observe_ping(9,100)
	check(not p.high_ping() and not p.required(game),"Sustained recovery below 140 returns to aim-only")
	for i in 8: p.observe_ping(3,180)
	check(p.high_ping(),"Any player's sustained high ping enables fallback")
	a.kit = Kits.get_kit("Null"); b.kit = Kits.get_kit("Ember")
	check(not p.required(game),"No aiming character still means no unused tracking, even with high ping")
	p.reset(); check(p.modes.is_empty() and p.peers.is_empty(),"New round clears aim and ping state")
	game.aimed_combat = null
	print("Aim tracking checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
