extends RefCounted

const Layout = preload("res://scripts/arena_layout.gd")

var grid := AStarGrid2D.new()

func _init() -> void:
	var width := Layout.GRID_MAX - Layout.GRID_MIN + 1
	grid.region = Rect2i(Layout.GRID_MIN, Layout.GRID_MIN, width, width)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(Layout.GRID_MIN, Layout.GRID_MAX + 1):
		for z in range(Layout.GRID_MIN, Layout.GRID_MAX + 1):
			var cell := Vector2i(x, z)
			grid.set_point_solid(cell, Layout.is_navigation_blocked(cell))

func nearest(pos: Vector3) -> Vector2i:
	var cell := Vector2i(clampi(roundi(pos.x), Layout.GRID_MIN, Layout.GRID_MAX), clampi(roundi(pos.z), Layout.GRID_MIN, Layout.GRID_MAX))
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
