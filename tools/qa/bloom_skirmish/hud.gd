extends SceneTree
## Independent redesigned HUD state, layout and intent wiring. Not visual acceptance.
const HUD = preload("res://modules/bloom_skirmish/ui/bloom_hud.gd")
const Rules = preload("res://modules/bloom_skirmish/sim.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok and failures.size() < 60:
  failures.append(label)
  printerr("FAIL HUD ",label)
func screen_rect(control: Control) -> Rect2:
 return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,control.size)
func contained(control: Control, label: String) -> void:
 var rect := screen_rect(control)
 var viewport_rect := Rect2(Vector2.ZERO,root.get_visible_rect().size).grow(.1)
 check(rect.position.is_finite() and rect.size.is_finite() and rect.size.x > 0 and rect.size.y > 0 and viewport_rect.encloses(rect),label+": finite and within viewport")
func live_state() -> Dictionary:
 return {"green":32.4,"coral":48.6,"time":81.01,"hp":37,"water":13.2,"dash_cd":Rules.DASH_COOLDOWN*.5,"pod_cd":Rules.POD_COOLDOWN*.75,"audio":false,"pointer_active":true,"countdown":0,"alive":true,"finished":false,"paused":false,"roster":[{"team":0,"alive":true,"player":true},{"team":0,"alive":false,"player":false},{"team":1,"alive":false,"player":false},{"team":1,"alive":true,"player":false}]}
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 await process_frame
 var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.content_scale_size=Vector2i.ZERO
 var hud = HUD.new(); root.add_child(hud); hud.set_process(false)
 var intents := {"pause":0,"restart":0,"exit":0,"audio":0}
 hud.pause_requested.connect(func():intents.pause+=1)
 hud.restart_requested.connect(func():intents.restart+=1)
 hud.exit_requested.connect(func():intents.exit+=1)
 hud.audio_requested.connect(func():intents.audio+=1)
 for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1280,800),Vector2i(1024,768)]:
  root.size=dimensions
  await process_frame
  await process_frame
  hud._layout()
  var data := live_state()
  var untouched := data.duplicate(true)
  hud.update_state(data)
  check(data==untouched,"HUD never mutates gameplay state")
  check(hud.health.value==37 and is_equal_approx(hud.water.value,13.2),"health and finite water reflect actual values")
  check(hud.health_text.text=="37" and hud.water_text.text=="14","resource numbers match rounded actual bars")
  check(hud.clock_label.text=="1:22","timer rounds remaining time upward, not a design mock number")
  check(hud.score_green.text=="32.4%" and hud.score_coral.text=="48.6%","both territory percentages are live")
  check(is_equal_approx(hud.cover_green.size.x/HUD.SCORE_WIDTH,.324) and is_equal_approx(hud.cover_coral.size.x/HUD.SCORE_WIDTH,.486),"coverage strip preserves authoritative percentages")
  check(is_equal_approx(hud.cover_coral.position.x+hud.cover_coral.size.x,HUD.SCORE_WIDTH),"opponent coverage remains right anchored")
  check(hud.team_markers.size()==4,"exactly two indicators per team, never concept-art 4v4")
  check(hud.team_markers.map(func(marker):return marker.active)==[true,false,false,true],"roster shows both teams' actual defeat state")
  check(hud.team_markers.map(func(marker):return marker.is_player)==[true,false,false,false],"exactly one human marker")
  check(hud.team_markers[0].kind==hud.team_markers[1].kind and hud.team_markers[2].kind==hud.team_markers[3].kind and hud.team_markers[0].kind!=hud.team_markers[2].kind,"teams retain distinct non-color icon identities")
  check(is_equal_approx(hud.dash_fill.value,50) and is_equal_approx(hud.pod_fill.value,25),"ability recharge derives from actual simulation cooldowns")
  check(hud.dash_text.text.contains("1.5") and hud.pod_text.text.contains("9.0"),"cooldown numerals reflect state")
  check(hud.mute_icon.kind=="mute","audio state updates icon")
  check(not hud.intro.visible and not hud.modal.visible and not hud.center_group.visible and hud.overlay.crosshair_on,"live game removes intro/large center panel and retains reticle")
  check(hud.overlay.target.is_equal_approx(root.get_visible_rect().size*.5),"reticle tracks actual viewport center")
  for control in [hud.score_strip,hud.utility_controls,hud.resources,hud.dash_card,hud.pod_card,hud.hint,hud.toast]:
   contained(control,"%s at %s"%[control.name,dimensions])
  # Native ProgressBar minimum-size/theme ordering previously inflated a 3–5px
  # meter to 27px while its outer panel still passed. Measure the actual child.
  for meter_spec in [[hud.health,hud.resources,Vector2(194,5)],[hud.water,hud.resources,Vector2(194,4)],[hud.dash_fill,hud.dash_card,Vector2(96,3)],[hud.pod_fill,hud.pod_card,Vector2(96,3)]]:
   var meter: ProgressBar=meter_spec[0]
   var panel: Control=meter_spec[1]
   check(meter.size.is_equal_approx(meter_spec[2]),"actual thin meter is not expanded by native minimum-size/theme ordering")
   check(not meter.show_percentage,"thin meter never reserves native percentage text height")
   check(screen_rect(panel).grow(.1).encloses(screen_rect(meter)),"actual meter remains inside its visible resource/ability panel")
   contained(meter,"actual meter at %s"%dimensions)
  for resource_label in [hud.health_text,hud.water_text,hud.water_status]:
   check(screen_rect(hud.resources).grow(.1).encloses(screen_rect(resource_label)),"resource label stays within its own panel")
  check(screen_rect(hud.score_strip).size.y/root.get_visible_rect().size.y<=.075,"score strip uses at most 7.5% of height")
  var center := root.get_visible_rect().size*.5
  for control in [hud.score_strip,hud.utility_controls,hud.resources,hud.dash_card,hud.pod_card]:
   check(not screen_rect(control).grow(20).has_point(center),"persistent HUD leaves center aim area clear")
  var low_water_warning: String= hud.water_status.text
  data.water=100; data.hp=100; data.dash_cd=0; data.pod_cd=0; data.audio=true
  hud.update_state(data)
  check(hud.water_status.text!=low_water_warning and hud.dash_fill.value==100 and hud.pod_fill.value==100,"refilled resources and ready abilities clear old warnings")
  check(hud.mute_icon.kind=="sound","unmute updates icon")
  data.pointer_active=false; data.countdown=3
  hud.update_state(data)
  check(hud.intro.visible and not hud.overlay.crosshair_on and not hud.center_group.visible,"capture gate is explicit and has no live reticle")
  contained(hud.intro,"intro at %s"%dimensions)
  data.pointer_active=true; data.countdown=2.2
  hud.update_state(data)
  check(not hud.intro.visible and hud.center_group.visible and hud.center_title.text=="3" and not hud.overlay.crosshair_on,"captured countdown has correct number and blocks reticle")
  contained(hud.center_group,"countdown at %s"%dimensions)
  data.countdown=0; data.alive=false; data.respawn=3.6
  hud.update_state(data)
  check(hud.center_group.visible and hud.center_title.text=="3.6" and not hud.overlay.crosshair_on,"defeat has actual respawn timer and no active reticle")
  data.alive=true; data.paused=true
  hud.update_state(data)
  check(hud.modal.visible and hud.scrim.visible and hud.restart_action.visible and not hud.overlay.crosshair_on,"pause exposes continue/restart/return without active aiming")
  check(hud.action.has_focus(),"new modal has an actionable keyboard focus")
  for control in [hud.modal,hud.action,hud.restart_action,hud.result_return]: contained(control,"pause control at %s"%dimensions)
  var hint_time: float=hud.hint_elapsed
  hud._process(.7)
  check(hud.hint_elapsed==hint_time,"pause does not consume control-help time")
  var pause_before: int=intents.pause
  hud.action.pressed.emit()
  check(intents.pause==pause_before+1,"continue emits exactly one pause intent")
  var restart_before: int=intents.restart
  hud.restart_action.pressed.emit()
  check(intents.restart==restart_before+1,"pause restart emits exactly one restart intent")
  data.paused=false; hud.update_state(data)
  check(not hud.modal.visible and not hud.scrim.visible and hud.overlay.crosshair_on,"continue restores unobstructed live HUD")
  for winner in [-1,0,1]:
   data.finished=true; data.winner=winner; data.time=0
   hud.update_state(data)
   check(hud.modal.visible and hud.scrim.visible and not hud.restart_action.visible and not hud.overlay.crosshair_on,"result has replay/return, no stale pause restart")
   check(hud.result_blue.text=="32.4%" and hud.result_orange.text=="48.6%","result preserves measured percentages independently of winner copy")
   for control in [hud.modal,hud.action,hud.result_return,hud.result_scores]: contained(control,"result control at %s"%dimensions)
   restart_before=intents.restart
   hud.action.pressed.emit()
   check(intents.restart==restart_before+1,"result action emits exactly one replay, not resume")
  var exit_before: int=intents.exit
  hud.result_return.pressed.emit()
  check(intents.exit==exit_before+1,"return emits exactly one exit intent")
  # Multiple state updates must not reconnect signals or retain modal state on replay.
  hud.update_state(live_state())
  check(not hud.modal.visible and not hud.scrim.visible and hud.overlay.crosshair_on,"replay fully clears result overlay state")
 check(intents.pause==4 and intents.restart==16 and intents.exit==4,"repeated view/state transitions never duplicate callbacks")
 hud.queue_free()
 await process_frame
 await process_frame
 check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline,"new HUD and signal graph free without orphans")
 print("BLOOM INDEPENDENT HUD: %d checks, %d failures; four viewport sizes, live/intro/countdown/defeat/pause/result and intent wiring; no visual-acceptance claim"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
