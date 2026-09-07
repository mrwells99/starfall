extends RefCounted

var grid := AStarGrid2D.new()

func _init() -> void:
	grid.region = Rect2i(-17, -17, 35, 35)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(-17, 18):
		for z in range(-17, 18):
			for px in [-6, 6]:
				for pz in [-5, 5]:
					if abs(x - px) <= 2 and abs(z - pz) <= 2:
						grid.set_point_solid(Vector2i(x, z))

func nearest(pos: Vector3) -> Vector2i:
	var cell := Vector2i(clampi(roundi(pos.x), -17, 17), clampi(roundi(pos.z), -17, 17))
	if not grid.is_point_solid(cell):
		return cell
	var best := Vector2i.ZERO
	var distance := INF
	for x in range(-3, 4):
		for y in range(-3, 4):
			var candidate := cell + Vector2i(x, y)
			if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
				var d := Vector2(candidate).distance_squared_to(Vector2(pos.x, pos.z))
				if d < distance:
					distance = d
					best = candidate
	return best

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	return grid.get_point_path(nearest(from), nearest(to))
