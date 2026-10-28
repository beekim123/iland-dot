extends Node3D
var elapsed := 0.0
var index := 0
const CLIPS := ["idle", "run", "grab", "swing", "air", "land", "fall"]
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 2.4:
		elapsed = 0.0
		index = (index + 1) % CLIPS.size()
		$Visual.play_pose(CLIPS[index])
		$CanvasLayer/Label.text = "ORIGINAL MONKEY RIG · " + CLIPS[index] + " · 22 bones / 10k tris"
