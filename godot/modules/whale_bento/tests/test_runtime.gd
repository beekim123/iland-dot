extends SceneTree
const Main=preload("res://modules/whale_bento/main.tscn")
var exit_count=0
func _initialize(): call_deferred("run")
func run():
 var save_path="user://games/whale_bento/run.json"
 var had_save=FileAccess.file_exists(save_path)
 var previous=FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
 var node=Main.instantiate()
 root.add_child(node)
 node.exit_requested.connect(func(): exit_count+=1)
 node.start({"game_id":"whale_bento","save_dir":"user://games/whale_bento","schema_version":1})
 node.start({})
 assert(node.started and node.hosted)
 await process_frame
 assert(node.buttons.size()>0)
 node.screen="game"
 node.model.reset(); node.model.skip(); node.model.place(0,4); node._save()
 var saved=JSON.parse_string(FileAccess.get_file_as_string(node.SAVE))
 var restored=preload("res://modules/whale_bento/rules.gd").new()
 assert(restored.restore(saved) and restored.board[4]==0)
 for phase in ["draft","serve","receipt","upgrade","lost","won"]:
  node.model.phase=phase
  node.model.last_result={"total":30,"cost":9,"profit":21}
  node.queue_redraw()
  await process_frame
  await process_frame
 for kind in ["help","pause",""]:
  node.overlay=kind; node.queue_redraw()
  await process_frame
 node.request_exit(); node.request_exit()
 assert(exit_count==1)
 node.queue_free(); await process_frame
 if had_save:
  var backup=FileAccess.open(save_path,FileAccess.WRITE)
  backup.store_buffer(previous)
 else: DirAccess.remove_absolute(save_path)
 print("Whale Bento runtime: title, phases, overlays, idempotent host exit passed")
 quit()
