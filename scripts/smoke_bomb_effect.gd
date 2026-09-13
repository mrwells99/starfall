extends Node3D
## Retained client-only billboard batch. No colliders, shadows, lights or server work.
const Smoke = preload("res://scripts/smoke_bomb.gd")
const COUNT := 36
static var puff_texture: ImageTexture
var puffs: MultiMeshInstance3D
var ring: MeshInstance3D
var ring_material: StandardMaterial3D
var centers := PackedVector3Array()
var sizes := PackedFloat32Array()
var age := 0.0
var previous_left := 0.0
var reduced := false

func _init() -> void:
	name="SmokeBombEffect";top_level=true;visible=false;set_process(false)
	if puff_texture == null:
		var noise:=FastNoiseLite.new();noise.seed=4187;noise.frequency=.065
		var image:=Image.create(96,96,false,Image.FORMAT_RGBA8)
		for y in 96:
			for x in 96:
				var radius:=Vector2(x-47.5,y-47.5).length()/47.5
				var alpha:=pow(maxf(0,1-radius*radius),2.0)*clampf(.73+noise.get_noise_2d(x,y)*.55,0,1)
				image.set_pixel(x,y,Color(1,1,1,alpha))
		puff_texture=ImageTexture.create_from_image(image)
	var material:=StandardMaterial3D.new()
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.billboard_keep_scale=true
	material.vertex_color_use_as_albedo=true;material.albedo_texture=puff_texture
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;quad.material=material
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_colors=true
	batch.mesh=quad;batch.instance_count=COUNT
	puffs=MultiMeshInstance3D.new();puffs.multimesh=batch
	puffs.scale=Vector3.ONE*(Smoke.RADIUS/5.0) # Scale the authored cloud with its gameplay radius.
	puffs.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(puffs)
	var rng:=RandomNumberGenerator.new();rng.seed=971
	for i in COUNT:
		# Authored at 5m, scaled above to feather before the current boundary ring.
		var angle:=i*2.399963
		var radius:=3.6*sqrt(float(i%18)/17.0)
		var height:=.75 if i<18 else 1.7+1.25*(1-radius/3.6)
		centers.append(Vector3(cos(angle)*radius,height,sin(angle)*radius))
		sizes.append(rng.randf_range(2.0,2.6))
	ring=MeshInstance3D.new();var mesh:=TorusMesh.new()
	mesh.inner_radius=Smoke.RADIUS-.045;mesh.outer_radius=Smoke.RADIUS
	mesh.rings=64;mesh.ring_segments=6;ring.mesh=mesh;ring.position.y=.065
	ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_material=StandardMaterial3D.new();ring_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring_material.albedo_color=Color(.65,.72,.79,.55)
	ring.material_override=ring_material;add_child(ring)

func sync(cloud: Dictionary, enabled: bool, reduced_effects: bool) -> void:
	var left:=float(cloud.get("left",0.0))
	if not enabled or left<=0:
		visible=false;previous_left=0;set_process(false);return
	var point:Vector3=cloud.position
	if not visible or point!=global_position or left>previous_left+.2:age=Smoke.DURATION-left
	else:age=maxf(age,Smoke.DURATION-left)
	global_position=point;previous_left=left;reduced=reduced_effects
	visible=true;set_process(true);_draw_cloud()

func _process(delta: float) -> void:
	age+=maxf(0,delta);_draw_cloud()

func _draw_cloud() -> void:
	var envelope:=smoothstep(0,.22,age)*smoothstep(0,.55,Smoke.DURATION-age)
	ring_material.albedo_color.a=.65*envelope
	puffs.visible=not reduced
	if reduced:return
	for i in COUNT:
		var phase:=age*1.45+i*.91
		var point:=centers[i]+Vector3(sin(phase)*.12,.10*sin(phase*.7),cos(phase)*.12)
		var size:=sizes[i]*(.95+.05*sin(phase*.8))
		puffs.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),point))
		var light:=.32+.045*sin(i*1.3)
		puffs.multimesh.set_instance_color(i,Color(light,light+.025,light+.055,envelope*(.72+.10*sin(phase))))
