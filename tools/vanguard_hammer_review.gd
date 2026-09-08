extends SceneTree
var triangle_count := 0
var mesh_count := 0
func _initialize() -> void:
 call_deferred("run")
func style(node: Node) -> void:
 if node is CollisionObject3D:
  push_error("Static review asset must not contain collision")
  quit(1)
 if node is MeshInstance3D:
  mesh_count += 1
  for i in node.mesh.get_surface_count():
   var original: Material = node.mesh.surface_get_material(i)
   var a: Array = node.mesh.surface_get_arrays(i)
   triangle_count += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] != null else a[Mesh.ARRAY_VERTEX].size()) / 3
   if original == null: continue
   var title := original.resource_name
   if "VioletCrystal" in title:
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/vanguard_crystal.gdshader")
    node.set_surface_override_material(i,mat)
   elif "ForgedSteel" in title or "WornEdges" in title or "OldTitanium" in title:
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/vanguard_forged.gdshader")
    mat.set_shader_parameter("base_color", original.albedo_color)
    node.set_surface_override_material(i,mat)
 for child in node.get_children(): style(child)
func capture(filename: String) -> void:
 for i in 12: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/vanguard/"+filename+".png")
func run() -> void:
 if DisplayServer.get_name()=="headless":
  quit(1)
  return
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 DisplayServer.window_set_size(Vector2i(1400,1000))
 root.size=Vector2i(1400,1000)
 var arena = load("res://arena.tscn").instantiate()
 root.add_child(arena)
 arena.set_process(false)
 arena.set_physics_process(false)
 arena.ui.hide()
 var packed: PackedScene = load("res://assets/characters/vanguard_hammer.glb")
 var model := packed.instantiate()
 arena.add_child(model)
 model.rotation.y=PI
 style(model)
 print("Hammer study mesh instances=",mesh_count," triangles=",triangle_count)
 var camera := Camera3D.new()
 arena.add_child(camera)
 camera.position=Vector3(3.1,1.9,-4.3)
 camera.fov=39
 camera.look_at(Vector3(-0.15,1.05,0))
 camera.current=true
 await capture("hammer-study-front")
 camera.position=Vector3(-3.4,1.9,-4.0)
 camera.look_at(Vector3(-0.15,1.05,0))
 await capture("hammer-study-other-side")
 camera.position=Vector3(2.5,2.1,4.0)
 camera.look_at(Vector3(0,1.05,0))
 await capture("hammer-study-back")
 # Save an independently loadable review scene, with the real shader overrides.
 var scene := PackedScene.new()
 model.owner=null
 for node in model.find_children("*","Node",true,false): node.owner=model
 scene.pack(model)
 ResourceSaver.save(scene,"res://assets/characters/vanguard_hammer_study.scn",ResourceSaver.FLAG_COMPRESS)
 quit()
