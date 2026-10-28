extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 var app=load("res://app/main.tscn").instantiate();root.add_child(app)
 for n in 5:await process_frame
 print("VP ",root.get_visible_rect()," transform ",root.get_screen_transform())
 print("MENU root ",app.hub_menu.root_control.get_global_rect()," catalog ",app.hub_menu.catalog_button.get_global_rect()," shuffle ",app.hub_menu.shuffle_button.get_global_rect()," vis ",app.hub_menu.visible)
 for p in app.hub.portals:
  var screen=app.island.camera.unproject_position(p.global_position+Vector3(0,1.85,0));var picked=app.hub._pick(screen)
  print("PORTAL ",p.game_id," pos ",p.global_position," screen ",screen," picks ",picked.get_path() if picked else "none")
 app.open_catalog()
 for n in 3:await process_frame
 print("OPEN ",app.catalog_open," size ",app.catalog.size," control ",app.catalog.get_global_rect()," visible ",app.catalog.visible)
 app.queue_free();await process_frame;await create_timer(.7).timeout;quit()
