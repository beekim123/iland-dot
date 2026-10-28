extends Node3D
const MAPS = preload("res://modules/beach_cleanup/data/maps.gd")
const BEACH = preload("res://modules/beach_cleanup/art/environment/beach_environment.gd")
var map_id := 0
var restored := false
var output := ""
func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--map="):
   map_id = int(arg.trim_prefix("--map="))
  if arg.begins_with("--output="):
   output = arg.trim_prefix("--output=")
  if arg == "--restored":
   restored = true
 var data: Dictionary = MAPS.definition(map_id,0)
 var beach := BEACH.new()
 add_child(beach)
 beach.build(data)
 if restored:
  var ids: Array = []
  for zone in data.zones:
   ids.append(zone.id)
  beach.update_state({"restored_zones":ids})
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = data.size.x*1.55
 camera.position = Vector3(23,33,31)
 add_child(camera)
 camera.look_at(Vector3.ZERO)
 camera.current = true
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-54,-32,0)
 sun.light_color = Color("fff9ef")
 sun.light_energy = 0.7
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 85
 add_child(sun)
 var world := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("d9d5c4")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("c4d4d0")
 env.ambient_light_energy = 0.25
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 world.environment = env
 add_child(world)

 if not output.is_empty():
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  var error := get_viewport().get_texture().get_image().save_png(output)
  print("BEACH_PREVIEW_SAVE ",output," error=",error)
  get_tree().quit(error)
