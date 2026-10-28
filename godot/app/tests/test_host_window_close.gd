extends SceneTree
## Process-level headless notification dispatch, not a native window-manager click.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var id:String=OS.get_cmdline_user_args()[0]
 var app=load("res://app/main.tscn").instantiate();root.add_child(app)
 await process_frame
 if not app.launch_game(id):printerr("FAIL close-probe launch ",id);quit(1);return
 await process_frame
 # Godot's propagated window notification can reach shell and module. Closing
 # the shell must remain idempotent and quit, not resurrect the catalogue.
 app.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 if not app.application_closing:printerr("FAIL host close was not accepted");quit(1);return
 print("HOST_WM_CLOSE_ACCEPTED: ",id)
 await create_timer(3).timeout
 printerr("FAIL host did not quit after window close");quit(1)
