extends SceneTree
const Rules=preload("res://modules/whale_bento/rules.gd")
func _initialize():
 var m=Rules.new(); m.reset(); m.skip(); m.place(0,4)
 var encoded=JSON.stringify(m.snapshot())
 var copy=Rules.new()
 assert(copy.restore(JSON.parse_string(encoded)))
 assert(copy.board[4]==0 and copy.stock[0]==1 and copy.coins==18)
 assert(not copy.restore({}))
 var invalid=JSON.parse_string(encoded); invalid.board[0]=99
 assert(not copy.restore(invalid))
 invalid=JSON.parse_string(encoded); invalid.day=4
 assert(not copy.restore(invalid))
 invalid=JSON.parse_string(encoded); invalid.phase="foreign"
 assert(not copy.restore(invalid))
 for key in ["coins","offers","last_result","stock"]:
  invalid=JSON.parse_string(encoded); invalid.erase(key)
  assert(not copy.restore(invalid))
 invalid=JSON.parse_string(encoded); invalid.offers=[-1,6,100]
 assert(not copy.restore(invalid))
 invalid=JSON.parse_string(encoded); invalid.stock="corrupt"
 assert(not copy.restore(invalid))
 invalid=JSON.parse_string(encoded); invalid.phase="upgrade"
 assert(not copy.restore(invalid))
 print("Whale Bento storage: JSON roundtrip + corrupt save rejection passed")
 quit()
