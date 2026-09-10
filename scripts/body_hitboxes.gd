extends RefCounted
## Damage volumes are independent of terrain/movement collision. Dimensions in meters.
const PARTS := ["pelvis", "abdomen", "chest", "neck", "head", "shoulder.L", "upper_arm.L", "forearm.L", "hand.L", "thigh.L", "shin.L", "foot.L", "shoulder.R", "upper_arm.R", "forearm.R", "hand.R", "thigh.R", "shin.R", "foot.R"]
var rig: Skeleton3D
var indices := {}
var radii := PackedFloat32Array()
var points := PackedVector3Array()
var bounds := AABB()

func setup(skeleton: Skeleton3D, title: String) -> void:
	rig = skeleton
	for i in rig.get_bone_count(): indices[rig.get_bone_name(i)] = i
	# About 2–4 cm of forgiveness around the main body; Vanguard includes its thicker plate.
	var heavy := title == "Vanguard"
	radii = PackedFloat32Array([.175 if heavy else .145, .205 if heavy else .175, .245 if heavy else .205, .085, .155 if heavy else .145])
	for side in 2:
		radii.append_array(PackedFloat32Array([.145 if heavy else .105, .125 if heavy else .100, .115 if heavy else .09, .085 if heavy else .07, .145 if heavy else .12, .12 if heavy else .10, .10 if heavy else .085]))
	points.resize(PARTS.size()*2)
	update()

func bone(name: String, offset := Vector3.ZERO) -> Vector3:
	return rig.global_transform * (rig.get_bone_global_pose(indices["DEF-"+name]) * offset)

func segment(index: int, start: Vector3, end: Vector3) -> void:
	points[index*2] = start; points[index*2+1] = end

func update() -> void:
	rig.force_update_all_bone_transforms()
	segment(0,bone("thigh.L"),bone("thigh.R"))
	segment(1,bone("spine.001"),bone("spine.002"))
	segment(2,bone("spine.002"),bone("spine.003",Vector3(0,.075,0)))
	segment(3,bone("neck"),bone("head"))
	segment(4,bone("head",Vector3(0,.07,0)),bone("head",Vector3(0,.14,0)))
	for side in 2:
		var suffix: String = ".L" if side == 0 else ".R"
		var k := 5 + side*7
		segment(k,bone("upper_arm"+suffix),bone("upper_arm"+suffix,Vector3(0,.045,0)))
		segment(k+1,bone("upper_arm"+suffix),bone("forearm"+suffix))
		segment(k+2,bone("forearm"+suffix),bone("hand"+suffix))
		segment(k+3,bone("hand"+suffix),bone("hand"+suffix,Vector3(0,.08,0)))
		segment(k+4,bone("thigh"+suffix),bone("shin"+suffix))
		segment(k+5,bone("shin"+suffix),bone("foot"+suffix))
		segment(k+6,bone("foot"+suffix),bone("toe"+suffix))
	bounds = bounds_for(points,radii)

static func bounds_for(samples: PackedVector3Array, sizes: PackedFloat32Array) -> AABB:
	var box := AABB(samples[0],Vector3.ZERO)
	for i in sizes.size():
		var padding := Vector3.ONE*sizes[i]
		for j in 2:
			box = box.expand(samples[i*2+j]-padding).expand(samples[i*2+j]+padding)
	return box

static func sphere_distance(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> float:
	var offset := origin-center
	var c := offset.length_squared()-radius*radius
	if c <= 0: return 0.0
	var b := offset.dot(direction)
	var discriminant := b*b-c
	if discriminant < 0: return INF
	var t := -b-sqrt(discriminant)
	return t if t >= 0 else INF

static func capsule_distance(origin: Vector3, direction: Vector3, start: Vector3, end: Vector3, radius: float) -> float:
	var axis := end-start
	var length_squared := axis.length_squared()
	if length_squared < .0000001: return sphere_distance(origin,direction,start,radius)
	var offset := origin-start
	var along := axis.dot(offset)
	var closest := start+axis*clampf(along/length_squared,0,1)
	if origin.distance_squared_to(closest) <= radius*radius: return 0.0
	var dot_direction := axis.dot(direction)
	var aa := length_squared-dot_direction*dot_direction
	var bb := length_squared*offset.dot(direction)-along*dot_direction
	var cc := length_squared*(offset.length_squared()-radius*radius)-along*along
	var hit := minf(sphere_distance(origin,direction,start,radius),sphere_distance(origin,direction,end,radius))
	var discriminant := bb*bb-aa*cc
	if aa > .0000001 and discriminant >= 0:
		var t := (-bb-sqrt(discriminant))/aa
		var y := along+t*dot_direction
		if t >= 0 and y >= 0 and y <= length_squared: hit = minf(hit,t)
	return hit

static func trace(origin: Vector3, direction: Vector3, limit: float, samples: PackedVector3Array, sizes: PackedFloat32Array) -> Dictionary:
	if bounds_for(samples,sizes).intersects_segment(origin,origin+direction*limit) == null: return {}
	var closest := limit
	var part := -1
	for i in sizes.size():
		var distance := capsule_distance(origin,direction,samples[i*2],samples[i*2+1],sizes[i])
		if distance < closest:
			closest = distance; part = i
	return {"distance":closest,"part":PARTS[part],"position":origin+direction*closest} if part >= 0 else {}
