extends RefCounted

# Gameplay dimensions shared by physical geometry and the bot path grid.
# Decoration may extend beyond these footprints, but must not add collision.
const HALF_EXTENT := 18.0
const GRID_MIN := -17
const GRID_MAX := 17
const BOUNDARY_THICKNESS := 0.7
const BOUNDARY_HEIGHT := 3.0
const COVER_BODY_SIZE := Vector3(4.4, 3.8, 2.8)
const COVER_BASE_SIZE := Vector3(4.7, 0.4, 3.3)
const COVER_CLEARANCE := Vector2i(3, 2)
const TERRACE_INNER := 12.3
const TERRACE_OUTER := 17.65
const TERRACE_HALF_LENGTH := 6.0
const RAMP_END := 10.0
const TERRACE_HEIGHT := 1.2

static func cover_centers() -> Array[Vector3]:
	return [Vector3(-6, 0, -5), Vector3(-6, 0, 5), Vector3(6, 0, -5), Vector3(6, 0, 5)]

static func is_navigation_blocked(cell: Vector2i) -> bool:
	for center in cover_centers():
		if absf(cell.x - center.x) <= COVER_CLEARANCE.x and absf(cell.y - center.z) <= COVER_CLEARANCE.y:
			return true
	# Keep capsules clear of both the terrace ledge and the raised ramp sides.
	# Entry is through the ramp mouths at z = +/-10, where the surface is level.
	var ledge_x := floori(TERRACE_INNER)
	return absi(cell.x) in [ledge_x, ledge_x + 1] and absf(cell.y) < RAMP_END

static func surface_height(pos: Vector3) -> float:
	if absf(pos.x) < TERRACE_INNER or absf(pos.x) > TERRACE_OUTER:
		return 0.0
	if absf(pos.z) <= TERRACE_HALF_LENGTH:
		return TERRACE_HEIGHT
	if absf(pos.z) < RAMP_END:
		return TERRACE_HEIGHT * (RAMP_END - absf(pos.z)) / (RAMP_END - TERRACE_HALF_LENGTH)
	return 0.0
