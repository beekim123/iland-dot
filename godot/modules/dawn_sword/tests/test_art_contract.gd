extends SceneTree
const BASE = "res://modules/dawn_sword/art/"
func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json"))
	var checks: int = 0
	var pending: int = 0
	for id in manifest.actors:
		var actor: Dictionary = manifest.actors[id]
		assert(not ".." in actor.file and not "://" in actor.file)
		var image := Image.new()
		assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(BASE+actor.file)) == OK)
		assert(image != null and not image.is_empty())
		assert(image.get_format() == Image.FORMAT_RGBA8)
		assert(actor.frame_width*actor.columns<=image.get_width())
		assert(actor.frame_height*actor.rows<=image.get_height())
		assert(actor.height>0 and actor.height<=600)
		for action in actor.animations:
			var animation: Dictionary = actor.animations[action]
			var start: int = int(animation.get("start",0))
			var count: int = int(animation.get("frames",1))
			assert(start>=0 and count>=1 and start+count<=actor.columns*actor.rows)
			assert(animation.get("fps",0)>0)
			checks += 1
		pending += actor.get("pending",[]).size()
	for id in manifest.get("props",{}):
		var prop: Dictionary = manifest.props[id]
		assert(not ".." in prop.file and not "://" in prop.file)
		assert(FileAccess.file_exists(BASE+prop.file))
		if prop.has("tile_top_ratio"): assert(prop.tile_top_ratio>=0 and prop.tile_top_ratio<=1)
		checks += 1
	assert(manifest.backgrounds.size() == 5)
	var seen_backgrounds: Array = []
	for background in manifest.backgrounds:
		if background is Dictionary:
			for layer in ["far","mid"]:
				var path: String = background[layer]
				assert(not ".." in path and not "://" in path and FileAccess.file_exists(BASE+path))
				assert(not seen_backgrounds.has(path))
				seen_backgrounds.append(path)
				checks += 1
		else: assert(FileAccess.file_exists(BASE+str(background)))
	print("PASS art manifest geometry ",checks," checks; pending animation entries=",pending,". NOT visual/motion acceptance.")
	quit()
