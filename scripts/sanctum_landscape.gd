extends Node3D
## Batched, collision-free landscape. Large forms live beyond the boundary;
## the island's hanging foundations remain below the playable floor.
const Geometry = preload("res://scripts/arena_geometry.gd")
const CliffShader = preload("res://shaders/sanctum_cliff.gdshader")
var _geo: RefCounted
var _rock: ShaderMaterial
var _far_rock: ShaderMaterial
var _ruin: StandardMaterial3D
var _bronze: StandardMaterial3D
var _energy: StandardMaterial3D

func build() -> void:
	name = "SanctumLandscape"
	_geo = Geometry.new()
	_rock = _cliff("46556d", .78)
	_far_rock = _cliff("53627d", .52)
	_ruin = StandardMaterial3D.new()
	_ruin.albedo_color = Color("53617a")
	_ruin.albedo_texture = load("res://assets/environment/slice/textures/basalt_albedo.png")
	_ruin.uv1_scale = Vector3(.25,.25,.25)
	_ruin.uv1_triplanar = true
	_ruin.roughness = .87
	_bronze = StandardMaterial3D.new()
	_bronze.albedo_color = Color("8a7562")
	_bronze.metallic = .45
	_bronze.roughness = .68
	_energy = StandardMaterial3D.new()
	_energy.albedo_color = Color("233c5a")
	_energy.emission_enabled = true
	_energy.emission = Color("5c80c8")
	_energy.emission_energy_multiplier = 2.3
	# The principal keel reads as one island, instead of a fence of thin spikes.
	_mass(_rock, Vector3(0,-3.5,0), Vector2(44,44), 32.0, .3, 1)
	for side in [-1.0,1.0]:
		_mass(_rock,Vector3(side*23,-8,0),Vector2(12,31),23,.15*side,7)
		# Broken approach causeways terminate well outside the arena wall.
		_causeway(side)
	# Six intentionally spaced formations leave open space around the portals.
	for item in [
		[Vector3(-58,-8,-54),Vector2(37,27),44.0,.25,11],
		[Vector3(63,-5,-48),Vector2(31,30),48.0,-.4,23],
		[Vector3(-71,-13,11),Vector2(36,32),39.0,.65,37],
		[Vector3(70,-10,22),Vector2(34,26),43.0,-.65,41],
		[Vector3(-52,-12,67),Vector2(38,29),46.0,.2,53],
		[Vector3(56,-7,64),Vector2(32,31),41.0,-.25,61]]:
		var center: Vector3 = item[0]
		var size: Vector2 = item[1]
		_mass(_rock,center,size,item[2],item[3],item[4])
		_mass(_rock,center+Vector3(-size.x*.19,9,-size.y*.12),size*.56,15,item[3]+.3,item[4]+2)
		_mass(_rock,center+Vector3(size.x*.20,4,size.y*.06),size*.46,12,item[3]-.3,item[4]+3)
		_temple(center+Vector3(-size.x*.19,10,-size.y*.12),item[3],item[4])
	# Lower, receding shelves give the void a horizon without filling the sky.
	for i in range(9):
		var angle := TAU*(float(i)+.3)/9.0
		var center := Vector3(cos(angle)*133,-23+sin(angle*3)*7,sin(angle)*133)
		_mass(_far_rock,center,Vector2(45,28),35,angle,i+80)
		if i%3 == 0:
			_temple(center+Vector3(0,1,0),angle,i+80)
	var mist := ShaderMaterial.new()
	mist.shader = load("res://shaders/sanctum_abyss_mist.gdshader")
	for height in [-17.0,-30.0,-44.0]:
		_geo.ring(mist,Vector3(0,height,0),107.0,156.0,0,TAU,96)
	_geo.finish(self)
	_geo = null
	for child in get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			child.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

func _cliff(color: String, strata: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CliffShader
	mat.set_shader_parameter("rock_color",Color(color))
	mat.set_shader_parameter("strata_scale",strata)
	mat.set_shader_parameter("slate",load("res://assets/environment/sanctum_slate.png"))
	return mat

func _mass(mat: Material, center: Vector3, size: Vector2, drop: float, yaw: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*793
	var basis := Basis(Vector3.UP,yaw)
	var rings: Array = []
	var sides := 26
	var outline := PackedFloat32Array()
	for i in range(sides):
		outline.append(rng.randf_range(.79,1.08))
	for level in range(7):
		var ring: Array[Vector3] = []
		var fraction: float = [0.0,.09,.23,.40,.58,.79,1.0][level]
		var width: float = [1.0,1.04,.84,.90,.66,.48,.17][level]
		for i in range(sides):
			var angle := TAU*i/sides
			var radius := outline[i]*width*(1.0+.06*sin(i*2.2+level*1.9))
			var point := Vector3(cos(angle)*size.x*.5*radius, -drop*fraction,
				sin(angle)*size.y*.5*radius)
			point.y += rng.randf_range(-.7,.7) * (1.0 if level==0 else 1.8)
			point.x += fraction*size.x*.13
			ring.append(center+basis*point)
		rings.append(ring)
	var normals: Array = []
	for level in range(7):
		var row: Array[Vector3] = []
		for i in range(sides):
			var around: Vector3 = rings[level][(i+1)%sides]-rings[level][(i+sides-1)%sides]
			var down: Vector3 = rings[mini(level+1,6)][i]-rings[maxi(level-1,0)][i]
			row.append(around.cross(down).normalized())
		normals.append(row)
	if not _geo.batches.has(mat):
		var batch := SurfaceTool.new()
		batch.begin(Mesh.PRIMITIVE_TRIANGLES)
		_geo.batches[mat] = batch
	var surface: SurfaceTool = _geo.batches[mat]
	for level in range(6):
		for i in range(sides):
			var next := (i+1)%sides
			for pair in [Vector2i(level,i),Vector2i(level+1,i),Vector2i(level+1,next),
				Vector2i(level,i),Vector2i(level+1,next),Vector2i(level,next)]:
				var p: Vector3 = rings[pair.x][pair.y]
				surface.set_normal(normals[pair.x][pair.y])
				surface.set_color(Color.WHITE)
				surface.set_uv(Vector2(p.x,p.z))
				surface.add_vertex(p)
	for i in range(sides):
		_geo.triangle(mat,center,rings[0][(i+1)%sides],rings[0][i])
		_geo.triangle(mat,center+Vector3(size.x*.13,-drop-.7,0),rings[6][i],rings[6][(i+1)%sides])

func _temple(origin: Vector3, yaw: float, seed_value: int) -> void:
	var basis := Basis(Vector3.UP,yaw)
	_geo.block(_ruin,origin,Vector3(13,.8,8),yaw)
	_geo.block(_ruin,origin+Vector3.DOWN*.6,Vector3(15,.5,10),yaw)
	for side in [-1.0,1.0]:
		for i in range(4):
			var local := Vector3(-5.1+i*3.4,0,side*2.8)
			var height := 7.5 if (i+seed_value)%3!=0 else 3.4
			_geo.block(_ruin,origin+basis*(local+Vector3.UP*(height*.5)),Vector3(.95,height,1.05),yaw)
			_geo.block(_ruin,origin+basis*(local+Vector3.UP*.65),Vector3(1.5,.3,1.5),yaw)
			_geo.block(_bronze,origin+basis*(local+Vector3.UP*(height-.3)),Vector3(1.24,.18,1.34),yaw)
		# Broken lintels make these identifiable temples, not more rock spires.
		_geo.block(_ruin,origin+basis*Vector3(-3.3,7.7,side*2.8),Vector3(4.5,.7,1.4),yaw)
	_geo.block(_ruin,origin+basis*Vector3(4.7,1.4,0),Vector3(1.2,2.4,5.6),yaw)
	# A collapsed apse gives the distant sanctuary a readable architectural
	# silhouette. These are closed stone wedges, with a gap at the crown.
	for i in range(13):
		if i == 6 or i == 7:
			continue
		var a := PI*float(i)/13.0+.015
		var b := PI*float(i+1)/13.0-.015
		var vertices: Array[Vector3] = []
		for z in [-.5,.5]:
			for radius in [2.3,2.9]:
				for angle in [a,b]:
					vertices.append(origin+basis*Vector3(cos(angle)*radius,4.3+sin(angle)*radius,z))
		for face in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[1,5,7,3],[0,2,6,4]]:
			_geo.quad(_ruin,vertices[face[0]],vertices[face[1]],vertices[face[2]],vertices[face[3]])
	for side in [-1.0,1.0]:
		_geo.block(_ruin,origin+basis*Vector3(side*2.6,2.1,0),Vector3(.65,4.2,1.0),yaw)
	var halo := origin+Vector3.UP*7.2
	for i in range(15):
		var a := -.15+i*.17
		var b := a+.14
		var points: Array[Vector3] = [halo+basis*Vector3(cos(a)*3,sin(a)*3,0),halo+basis*Vector3(cos(b)*3,sin(b)*3,0)]
		_geo.line_3d(_bronze,points,.19)
		if i%4==0:
			_geo.line_3d(_energy,points,.045)

func _causeway(side: float) -> void:
	for i in range(4):
		var x := side*(25.5+i*4.7)
		if i == 2:
			continue
		var y := -1.8-i*.65
		_geo.block(_ruin,Vector3(x,y,0),Vector3(4.2,.8,4.8),0)
		for z in [-2.1,2.1]:
			_geo.block(_ruin,Vector3(x,y+.6,z),Vector3(3.7,.7,.45),0)
		_mass(_rock,Vector3(x,y-.6,0),Vector2(4.5,5.1),7+i*2,0,120+i)
