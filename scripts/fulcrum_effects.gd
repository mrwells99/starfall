extends Node3D
## Snapshot-driven effects, allocated only by visible clients. No combat decisions here.
const Rules = preload("res://scripts/fulcrum_mechanics.gd")
const Clock = preload("res://scripts/snapshot_animation_clock.gd")
var actor
var reduced := false
var core: MeshInstance3D
var lens: MeshInstance3D
var spike: MeshInstance3D
var disk: MeshInstance3D
var blast: MeshInstance3D
var grass: MultiMeshInstance3D
var field_boundary: MeshInstance3D
var anchor_clock = Clock.new()
var field_clock = Clock.new()
var anchor_key := ""
var field_key := ""
var slashes := {}
var rifts := {}
var anchor_material: ShaderMaterial
var blast_material: ShaderMaterial
var grass_material: ShaderMaterial
static var sword_mesh: Mesh
static var energy_shader: Shader
static var growth_shader: Shader
const RUIN_FADE_IN := .018
const RUIN_FADE_OUT := .025

static func sword_opacity(age: float, divide: bool) -> float:
	var duration := Rules.DIVIDE_SECONDS if divide else Rules.RUIN_SECONDS
	return smoothstep(0,.04 if divide else RUIN_FADE_IN,age)*(1-smoothstep(duration,duration+(.65 if divide else RUIN_FADE_OUT),age))

static func sword_rotation(kind: String, progress: float) -> Vector3:
	if kind=="divide": return Vector3(lerpf(PI*.5,0,progress),0,PI*.5)
	var yaw := lerpf(-Rules.RUIN_HALF_ANGLE,Rules.RUIN_HALF_ANGLE,progress)
	return Vector3(0,yaw if kind=="ruin_left" else -yaw,0)

static func energy() -> Shader:
	if energy_shader!=null: return energy_shader
	energy_shader=Shader.new()
	energy_shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint: source_color = vec4(0.55,0.18,1.0,1.0);
uniform float opacity = 1.0;
uniform float glow = 2.2;
uniform bool shell = false;
uniform bool trail = false;
varying vec3 point;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){
 vec3 i=floor(p); vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){ point=VERTEX; }
void fragment(){
 float n=noise(point*8.0+vec3(TIME*.4,TIME*1.3,0.0))*.65+noise(point*19.0-vec3(TIME,0.0,TIME*.4))*.35;
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
 float thread=smoothstep(0.48,0.78,n);
 ALBEDO=mix(vec3(0.013,0.003,0.028),tint.rgb,0.12+rim*0.65+thread*0.25);
 EMISSION=tint.rgb*(rim*1.6+thread*0.5)*glow;
 ALPHA=opacity*tint.a*(shell ? (rim*0.65+thread*0.30) : 0.92);
 if(trail) ALPHA*=smoothstep(0.0,0.25,UV.x)*smoothstep(0.0,0.20,UV.y)*(1.0-smoothstep(0.85,1.0,UV.y))*0.35;
}"""
	return energy_shader

static func material(tint: Color, opacity: float = 1.0, shell: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); mat.shader=energy(); mat.set_shader_parameter("tint",tint); mat.set_shader_parameter("opacity",opacity); mat.set_shader_parameter("shell",shell)
	return mat

static func glow_material(tint: Color, emission: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color=tint
	mat.emission_enabled=true; mat.emission=tint; mat.emission_energy_multiplier=emission; mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return mat

static func mesh_node(parent: Node, mesh: Mesh, mat: Material, title: String) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name=title; node.mesh=mesh; node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(node)
	return node

static func sphere(radius: float = 1.0) -> SphereMesh:
	var mesh := SphereMesh.new(); mesh.radius=radius; mesh.height=radius*2; mesh.radial_segments=24; mesh.rings=12; return mesh

static func torus(radius: float, width: float) -> TorusMesh:
	var mesh := TorusMesh.new(); mesh.inner_radius=radius-width; mesh.outer_radius=radius; mesh.rings=64; mesh.ring_segments=8; return mesh

func _ready() -> void:
	name="FulcrumEffects"; top_level=true; transform=Transform3D.IDENTITY
	core=mesh_node(self,sphere(.62),glow_material(Color("07020e"),0),"BlackHole")
	lens=mesh_node(self,sphere(.72),material(Color("b471ff"),1,true),"EventHorizon")
	disk=mesh_node(self,torus(1.45,.45),material(Color("aa55ff"),.8),"AccretionDisk")
	disk.rotation=Vector3(.22,0,.16)
	var spike_mesh := CylinderMesh.new(); spike_mesh.top_radius=0; spike_mesh.bottom_radius=.28; spike_mesh.height=2.7; spike_mesh.radial_segments=7
	spike=mesh_node(self,spike_mesh,material(Color("bf84ff")),"DarkMatterSpike")
	blast_material=material(Color("a552ff"),1,true)
	blast=mesh_node(self,sphere(),blast_material,"ExpansionSphere")
	build_grass()
	for item in [core,lens,disk,spike,blast,grass,field_boundary]: item.hide()

func build_grass() -> void:
	if growth_shader==null:
		growth_shader=Shader.new(); growth_shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float radius=0.0;
uniform float fade=1.0;
varying float tip;
void vertex(){
 tip=UV.y;
 float reach=length(MODEL_MATRIX[3].xz);
 float grow=smoothstep(reach-0.45,reach+0.1,radius);
 VERTEX.y*=grow;
 VERTEX.x+=sin(TIME*2.5+reach*3.0)*0.08*tip*grow;
}
void fragment(){ ALBEDO=mix(vec3(0.006,0.002,0.012),vec3(0.22,0.065,0.38),pow(tip,4.0)); EMISSION=vec3(0.44,0.12,0.75)*pow(tip,9.0)*fade; }
"""
	# Growth uses per-instance custom distance rather than world-origin position.
	growth_shader.code=growth_shader.code.replace("length(MODEL_MATRIX[3].xz)","INSTANCE_CUSTOM.r*6.0")
	grass_material=ShaderMaterial.new(); grass_material.shader=growth_shader
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-.11,0,0),Vector3(.11,0,0),Vector3(.055,.64,.09)]:
		st.set_uv(Vector2(.5,1 if v.y>0 else 0)); st.add_vertex(v)
	st.generate_normals()
	var multimesh := MultiMesh.new(); multimesh.transform_format=MultiMesh.TRANSFORM_3D; multimesh.use_custom_data=true; multimesh.mesh=st.commit(); multimesh.instance_count=480
	for i in 480:
		var radius := sqrt((float(i)+.5)/480.0)*Rules.FIELD_RADIUS
		var angle := float(i)*2.39996323
		var transform := Transform3D(Basis(Vector3.UP,angle),Vector3(sin(angle)*radius,0,cos(angle)*radius))
		multimesh.set_instance_transform(i,transform); multimesh.set_instance_custom_data(i,Color(radius/6.0,0,0,1))
	grass=MultiMeshInstance3D.new(); grass.name="GrowingBlackGrass";grass.multimesh=multimesh;grass.material_override=grass_material; add_child(grass)
	field_boundary=mesh_node(self,torus(1,.02),glow_material(Color(.55,.24,.8,.38)),"GrowthBoundary")

func sync(a, reduced_effects: bool) -> void:
	actor=a; reduced=reduced_effects
	visible=a.hp>0

func _process(delta: float) -> void:
	if actor==null or not is_instance_valid(actor) or not visible: return
	paint_state(actor.identity,delta,actor.presentation_snapshot_serial,actor.motion_revision)

func paint_state(s: Dictionary, delta: float, snapshot: int = 0, revision: int = 0) -> void:
	var has_anchor: bool = s.anchor_left>0
	var compression: bool = s.get("anchor_kind","")=="anchor_compression"
	var key := str(s.get("anchor_serial",0))
	if key!=anchor_key: anchor_key=key;anchor_clock.reset()
	var age: float = anchor_clock.advance(s.get("anchor_age",0),delta,snapshot,revision,3.0)
	for item in [core,lens,disk,spike]: item.visible=has_anchor and compression
	if has_anchor:
		var center: Vector3 = s.anchor_pos+Vector3.UP*.7
		core.position=center;lens.position=center;disk.position=center;spike.position=s.anchor_pos+Vector3.UP*1.2
		var size := lerpf(1.6,1.0,smoothstep(0,.22,age))
		core.scale=Vector3.ONE*size;lens.scale=Vector3.ONE*size;disk.rotation.y=age*4
		spike.scale=Vector3.ONE*maxf(.001,smoothstep(.12,.28,age))
	blast.visible=has_anchor and not compression and age<.65
	if blast.visible:
		blast.position=s.anchor_pos+Vector3.UP*.6
		blast.scale=Vector3.ONE*maxf(.01,Rules.EXPANSION_RADIUS*smoothstep(0,.2,age))
		blast_material.set_shader_parameter("opacity",1-smoothstep(.2,.65,age))
	# Expansion keeps a small three-dimensional dark core during the follow-up.
	if has_anchor and not compression:
		core.show(); lens.show(); core.scale=Vector3.ONE*.45;lens.scale=Vector3.ONE*.5
		core.position=s.anchor_pos+Vector3.UP*.55;lens.position=core.position
	var field: Dictionary = s.get("gravity_field",{})
	grass.visible=not field.is_empty();field_boundary.visible=grass.visible
	if grass.visible:
		var next_field:=str(field.get("serial",field.position))
		if next_field!=field_key: field_key=next_field;field_clock.reset()
		var field_age: float = field_clock.advance(field.age,delta,snapshot,revision,6.0)
		var radius := Rules.FIELD_RADIUS*smoothstep(0,Rules.FIELD_GROWTH,field_age)
		# Keep the full radius legible at every graphics setting (480 triangles total).
		grass.position=field.position+Vector3.UP*.035; grass.multimesh.visible_instance_count=480
		grass_material.set_shader_parameter("radius",radius);grass_material.set_shader_parameter("fade",smoothstep(0,.6,float(field.left)))
		field_boundary.position=grass.position;field_boundary.scale=Vector3.ONE*maxf(.001,radius)
	var active: Array = []
	for event in s.get("fulcrum_slashes",[]):
		var id: int = event.serial; active.append(id)
		if not slashes.has(id): slashes[id]=make_slash(event)
		var data: Dictionary = slashes[id]
		var time: float = data.clock.advance(event.age,delta,snapshot,revision,1.2)
		paint_slash(data,event,time)
	for id in slashes.keys():
		if id not in active: slashes[id].root.queue_free();slashes.erase(id)
	active=[]
	for event in s.get("gravity_rifts",[]):
		active.append(event.serial)
		if not rifts.has(event.serial): rifts[event.serial]=make_rift(event)
		var node: Node3D = rifts[event.serial]
		for child in node.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				var tint: Color = child.material_override.albedo_color;tint.a=minf(1,float(event.left)/.7);child.material_override.albedo_color=tint
	for id in rifts.keys():
		if id not in active: rifts[id].queue_free();rifts.erase(id)

func make_slash(event: Dictionary) -> Dictionary:
	var root := Node3D.new();root.name="Sword_%s"%event.serial;add_child(root);root.position=event.position;root.rotation.y=event.yaw
	var pivot := Node3D.new();root.add_child(pivot);pivot.position.y=.8 if event.kind!="divide" else .18
	if sword_mesh==null: sword_mesh=load("res://assets/effects/fulcrum_dark_sword.obj")
	var mat := material(Color("9860f8"))
	var blade := mesh_node(pivot,sword_mesh,mat,"CommandedGreatsword")
	var length := Rules.DIVIDE_RANGE if event.kind=="divide" else Rules.RUIN_RANGE
	blade.scale=Vector3.ONE*length
	var halo := mesh_node(pivot,sword_mesh,material(Color("c09aff"),.35,true),"SwordAura");halo.scale=Vector3(length*1.07,length*1.9,length)
	var trail := mesh_node(root,ArrayMesh.new(),material(Color("bc82ff"),.55),"SlashTrail")
	trail.material_override.set_shader_parameter("trail",true)
	var smoke: Array = []
	for i in 12:
		var puff := mesh_node(pivot,sphere(.25),material(Color("593072"),.55,true),"Smoke_%s"%i)
		smoke.append(puff)
	return {"root":root,"pivot":pivot,"blade":blade,"halo":halo,"trail":trail,"smoke":smoke,"clock":Clock.new()}

func paint_slash(data: Dictionary, event: Dictionary, age: float) -> void:
	var divide: bool = event.kind=="divide"
	var duration := Rules.DIVIDE_SECONDS if divide else Rules.RUIN_SECONDS
	var progress := Rules.swing_progress(age/duration)
	var fade := sword_opacity(age,divide)
	# The downloaded blade lies in local XZ (Y is thickness). Keep its wide
	# axis tangent to horizontal travel; roll it 90 degrees for a vertical cut.
	data.pivot.rotation=sword_rotation(event.kind,progress)
	# Blade floats outside the palm; no hand/weapon attachment or body scaling.
	for item in [data.blade,data.halo]: item.material_override.set_shader_parameter("opacity",fade)
	var length := Rules.DIVIDE_RANGE if divide else Rules.RUIN_RANGE
	for i in data.smoke.size():
		var puff: MeshInstance3D = data.smoke[i];puff.visible=not reduced
		puff.position=Vector3(sin(age*9+i)*.15,.08+age*.2,-length*(.25+float(i)/16.0))
		puff.scale=Vector3.ONE*(1.0+float(i%3)*.5+age*1.5)
		puff.material_override.set_shader_parameter("opacity",fade*.4)
	data.root.visible=fade>.0001
	data.trail.visible=not reduced and age<duration+(.16 if divide else RUIN_FADE_OUT) and progress>.01
	if data.trail.visible:
		data.trail.mesh=arc_mesh(length,progress,divide,event.kind=="ruin_left")
		data.trail.material_override.set_shader_parameter("opacity",fade*.65)

static func arc_mesh(length: float, progress: float, divide: bool, left: bool) -> ArrayMesh:
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := maxf(0,progress-.32)
	for i in 24:
		var p0 := lerpf(previous,progress,float(i)/24);var p1 := lerpf(previous,progress,float(i+1)/24)
		var directions: Array[Vector3] = []
		for p in [p0,p1]:
			var angle := lerpf(0,PI*.5,p) if divide else lerpf(-Rules.RUIN_HALF_ANGLE,Rules.RUIN_HALF_ANGLE,p)
			directions.append(Vector3(0,cos(angle),-sin(angle)) if divide else Vector3(sin(angle)*(-1 if left else 1),0,-cos(angle)))
		var origin := Vector3.UP*(.18 if divide else .8)
		var points := [origin+directions[0]*length*.15,origin+directions[0]*length,origin+directions[1]*length,origin+directions[1]*length*.15]
		var uv := [Vector2(float(i)/24,0),Vector2(float(i)/24,1),Vector2(float(i+1)/24,1),Vector2(float(i+1)/24,0)]
		for index in [0,1,2,0,2,3]: st.set_uv(uv[index]);st.add_vertex(points[index])
	st.generate_normals();return st.commit()

func make_rift(event: Dictionary) -> Node3D:
	var root := Node3D.new();root.name="DivideRift_%s"%event.serial;add_child(root);root.position=event.position+Vector3.UP*.06;root.rotation.y=event.yaw
	var rng := RandomNumberGenerator.new();rng.seed=int(event.serial)+721
	var previous := Vector3.ZERO
	for i in 24:
		var point := Vector3(rng.randf_range(-.28,.28),0,-Rules.DIVIDE_RANGE*float(i+1)/24.0)
		var length := point.distance_to(previous)
		var box := BoxMesh.new();box.size=Vector3(.07,.025,length+.025)
		var line := mesh_node(root,box,glow_material(Color("ce91ff"),2.5),"Crack_%s"%i)
		line.position=(point+previous)*.5;line.rotation.y=atan2(-(point-previous).x,-(point-previous).z)
		if i%3==0:
			var branch_mesh := BoxMesh.new();branch_mesh.size=Vector3(.045,.02,.8)
			var branch := mesh_node(root,branch_mesh,glow_material(Color("9142d3"),1.4),"Branch_%s"%i)
			branch.position=point+Vector3(.3 if i%2==0 else -.3,0,0);branch.rotation.y=.9 if i%2==0 else -.9
		previous=point
	var bed_mesh := BoxMesh.new();bed_mesh.size=Vector3(Rules.DIVIDE_WIDTH,.015,Rules.DIVIDE_RANGE)
	var bed := mesh_node(root,bed_mesh,material(Color("622298"),.12,true),"RiftMiasma");bed.position.z=-Rules.DIVIDE_RANGE*.5
	return root
