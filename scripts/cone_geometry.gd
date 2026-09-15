extends RefCounted
## Shared Solar Flare / Ruin body-overlap test. No skeletal tracking or physics queries.
const BODY_RADIUS := .42
static func overlaps(origin: Vector3, yaw: float, position: Vector3, reach: float, half_angle: float, height: float = 1.8) -> bool:
	var offset := position-origin
	if absf(offset.y)>height: return false
	offset.y=0
	var distance := offset.length()
	if distance>reach+BODY_RADIUS: return false
	if distance<=BODY_RADIUS: return true
	var forward := -Basis(Vector3.UP,yaw).z
	var angle := acos(clampf(forward.dot(offset/distance),-1,1))
	return angle<=half_angle+asin(minf(1,BODY_RADIUS/distance))
