extends SceneTree
const Rules=preload("res://modules/whale_bento/rules.gd")
var checks=0
func check(ok:bool,message:String):
 if not ok:
  push_error(message); quit(1)
  assert(ok,message)
 checks+=1
func _initialize():
 var m=Rules.new(); m.reset()
 check(m.phase=="draft" and m.coins==18,"reset economy")
 check(not m.place(0,0),"draft blocks placement")
 check(not m.buy(0),"cannot buy unavailable offer")
 check(m.buy(m.offers[0]) and m.coins==15,"purchase charges once")
 check(not m.buy(m.offers[0]),"cannot duplicate purchase")
 check(not m.place(-1,0) and not m.place(12,0) and not m.place(0,9),"invalid moves rejected")
 m.board=[0,1,-1,-1,-1,-1,-1,-1,-1]
 check(m.evaluate().bonus==3,"orthogonal grain veg")
 m.board=[-1,-1,0,1,-1,-1,-1,-1,-1]
 check(m.evaluate().bonus==0,"row edge never wraps")
 m.board=[0,-1,-1,-1,1,-1,-1,-1,-1]
 check(m.evaluate().bonus==0,"diagonal is not adjacent")
 m.board=[0,1,2,-1,3,-1,-1,-1,-1]
 check(m.evaluate().bonus==12,"adjacency three colors center egg additive")
 check(m.evaluate().preference==0,"liked vegetable and disliked seafood cancel")
 m.board=[4,5,-1,-1,-1,-1,-1,-1,-1]
 check(m.evaluate().bonus==4,"fruit milk pair")
 m.board=[2,6,-1,-1,-1,-1,-1,-1,-1]
 check(m.evaluate().bonus==4,"sea citrus pair")
 m.reset(); m.skip()
 check(m.place(0,0) and m.stock[0]==1,"stock consumption")
 check(m.place(1,0) and m.stock[0]==2 and m.stock[1]==1,"replacement refunds old")
 check(m.remove(0) and m.stock[1]==2 and not m.remove(0),"remove refunds once")
 check(not m.serve(),"empty order blocked")
 for slot in 5: check(m.place([0,1,0,1,3][slot],slot),"valid placement")
 check(not m.place(2,8),"customer capacity blocks extra item")
 check(m.serve() and m.phase=="receipt" and m.order==1,"serve advances once")
 check(not m.serve(),"double serve rejected")
 check(m.advance() and m.phase=="draft","receipt continues")
 m.phase="serve"; m.order=2; m.coins=100; m.board=[0,1,3,4,5,0,-1,-1,-1]
 var profit=m.evaluate().profit
 check(m.serve() and m.coins==100+profit-Rules.RENT[0] and m.phase=="upgrade","third order pays rent")
 check(m.upgrade(0) and m.day==2 and m.enhancements[0]==1,"upgrade persists into day2")
 m.skip(); m.place(0,0)
 check(m.evaluate().base==5,"permanent ingredient +2 sale")
 m.reset(); m.phase="serve"; m.order=2; m.coins=-100; m.board=[0,1,3,4,5,0,-1,-1,-1]
 check(m.serve() and m.phase=="lost","rent debt loses")
 m.reset()
 check(m.day==1 and m.coins==18 and m.order==0 and m.enhancements[0]==0,"retry resets all state")
 m.day=3; m.order=8; m.coins=100; m.phase="serve"; m.board=[0,1,3,4,5,0,-1,-1,-1]
 # Day3 order8 is sea customer: exactly six ingredients.
 check(m.serve() and m.phase=="won","nine orders solvent wins")
 check(not m.next_day() and not m.advance(),"terminal state cannot advance")
 print("Whale Bento rules: %d checks passed"%checks); quit()
