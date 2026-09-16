extends "res://tests/network_fixture_arena.gd"
var scripted_move := Vector2.ZERO
var peak_packet := 0
func deliver_snapshot(round_epoch: int, seq: int, states: Array, round_phase: String, time: float, start_time: float) -> void:
	for peer in multiplayer.get_peers():
		peak_packet=maxi(peak_packet,var_to_bytes(Ember.snapshot_for(states,peer_actor(peer))).compress(FileAccess.COMPRESSION_DEFLATE).size())
	super.deliver_snapshot(round_epoch,seq,states,round_phase,time,start_time)
func gather_input(delta: float) -> void:
	if not actors.has(local_id): return
	if authoritative():
		apply_input(local_id,scripted_move,0,false,-1)
	else:
		input_seq+=1
		prediction.predict(self,actors[local_id],{"seq":input_seq,"move":scripted_move,"yaw":0.0,"jump":false,"delta":delta,"walk":false,"buffer":0.0})
		deliver_input(epoch,input_seq,scripted_move,0,0,-1,0,false,0,false)
