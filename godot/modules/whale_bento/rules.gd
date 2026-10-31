extends RefCounted
## Pure rules: no rendering, files, clocks, or external module dependencies.
const INGREDIENTS = [
 {"name":"云米团","tag":"grain","price":3,"cost":1,"color":"fff3c2","tip":"邻接蔬菜 +3"},
 {"name":"翡翠豆","tag":"veg","price":3,"cost":1,"color":"8bcda5","tip":"邻接米团 +3"},
 {"name":"珊瑚虾","tag":"sea","price":4,"cost":2,"color":"ee9683","tip":"邻接柠檬 +4"},
 {"name":"月牙蛋","tag":"egg","price":3,"cost":1,"color":"f4d675","tip":"放正中央 +4"},
 {"name":"星莓","tag":"sweet","price":4,"cost":2,"color":"e3859b","tip":"邻接奶冻 +4"},
 {"name":"云奶冻","tag":"milk","price":3,"cost":1,"color":"e9e2f2","tip":"邻接星莓 +4"},
 {"name":"日光柠","tag":"citrus","price":3,"cost":1,"color":"edcf69","tip":"邻接海鲜 +4"},
 {"name":"海苔卷","tag":"grain","price":4,"cost":2,"color":"5f9e87","tip":"邻接蔬菜 +3"},
 {"name":"雨露菇","tag":"veg","price":4,"cost":2,"color":"ba9ace","tip":"邻接米团 +3"},
 {"name":"贝壳鱼","tag":"sea","price":5,"cost":3,"color":"87c6d2","tip":"邻接柠檬 +4"},
 {"name":"蜜桃星","tag":"sweet","price":4,"cost":2,"color":"f0af85","tip":"邻接奶冻 +4"},
 {"name":"薄荷冻","tag":"milk","price":3,"cost":1,"color":"a2d4cc","tip":"邻接甜果 +4"}
]
const CUSTOMERS = [
 {"name":"邮差云兔","like":"veg","avoid":"sea","wish":"蔬菜 +3 / 海鲜 −3","count":5},
 {"name":"午睡小海獭","like":"sea","avoid":"sweet","wish":"海鲜 +3 / 甜果 −3","count":6},
 {"name":"星旅猫头鹰","like":"sweet","avoid":"veg","wish":"甜果 +3 / 蔬菜 −3","count":6}
]
const RENT = [42,62,78]
var day = 1
var order = 0
var coins = 18
var board: Array = []
var stock: Array = []
var enhancements: Array = []
var phase = "draft"
var offers: Array = []
var ledger: Array = []
var last_result: Dictionary = {}

func reset():
 day=1; order=0; coins=18; enhancements=[]; ledger=[]; last_result={}
 for i in 12: enhancements.append(0)
 new_order()

func customer() -> Dictionary:
 return CUSTOMERS[(order + day - 1) % 3]

func new_order():
 board=[]; stock=[]
 for i in 9: board.append(-1)
 for i in 12: stock.append(0)
 for i in 6: stock[i]=1
 stock[0]=2; stock[1]=2
 offers=[6+(order+day-1)%6,6+(order+day+1)%6,6+(order+day+3)%6]
 phase="draft"

func buy(id:int) -> bool:
 if phase!="draft" or not id in offers or coins<3: return false
 coins-=3; stock[id]+=2; phase="serve"; return true

func skip():
 if phase=="draft": phase="serve"

func place(id:int,slot:int) -> bool:
 if phase!="serve" or id<0 or id>=12 or slot<0 or slot>=9 or stock[id]<=0: return false
 if board[slot]<0 and evaluate().count>=customer().count: return false
 if board[slot]>=0: stock[board[slot]]+=1
 board[slot]=id; stock[id]-=1; return true

func remove(slot:int) -> bool:
 if phase!="serve" or slot<0 or slot>=9 or board[slot]<0: return false
 stock[board[slot]]+=1; board[slot]=-1; return true

func evaluate() -> Dictionary:
 var result={"base":0,"cost":0,"bonus":0,"preference":0,"total":0,"profit":0,"count":0,"reasons":[]}
 for s in 9:
  var id:int=board[s]
  if id<0: continue
  var item:Dictionary=INGREDIENTS[id]
  result.count+=1; result.base+=item.price+enhancements[id]*2; result.cost+=item.cost
  if item.tag==customer().like: result.preference+=3
  if item.tag==customer().avoid: result.preference-=3
  if item.tag=="egg" and s==4:
   result.bonus+=4; result.reasons.append("中心月牙蛋 +4")
  for n in [s+1,s+3]:
   if n>=9 or (n==s+1 and s%3==2) or board[n]<0: continue
   var other:String=INGREDIENTS[board[n]].tag
   var pair=[item.tag,other]
   if "grain" in pair and "veg" in pair:
    result.bonus+=3; result.reasons.append("米蔬相邻 +3")
   if "sea" in pair and "citrus" in pair:
    result.bonus+=4; result.reasons.append("柠香海鲜 +4")
   if "sweet" in pair and "milk" in pair:
    result.bonus+=4; result.reasons.append("果奶相邻 +4")
 for row in 3:
  var tags=[]
  for col in 3:
   var id:int=board[row*3+col]
   if id>=0 and not INGREDIENTS[id].tag in tags: tags.append(INGREDIENTS[id].tag)
  if tags.size()==3:
   result.bonus+=5; result.reasons.append("第%d行三色餐 +5"%(row+1))
 result.total=maxi(0,result.base+result.bonus+result.preference)
 result.profit=result.total-result.cost
 return result

func serve() -> bool:
 if phase!="serve": return false
 var result=evaluate()
 if result.count!=customer().count: return false
 coins+=result.profit; last_result=result; order+=1
 ledger.append(result.profit)
 if order%3==0:
  coins-=RENT[day-1]; last_result["rent"]=RENT[day-1]
  if coins<0: phase="lost"
  elif day==3: phase="won"
  else: phase="upgrade"
 else: phase="receipt"
 return true

func advance() -> bool:
 if phase!="receipt": return false
 new_order(); return true

func upgrade(id:int) -> bool:
 if phase!="upgrade" or id<0 or id>=12 or coins<6: return false
 coins-=6; enhancements[id]+=1; day+=1; new_order(); return true

func next_day() -> bool:
 if phase!="upgrade": return false
 day+=1; new_order(); return true

func snapshot() -> Dictionary:
 return {"day":day,"order":order,"coins":coins,"board":board,"stock":stock,"enhancements":enhancements,"phase":phase,"offers":offers,"ledger":ledger,"last_result":last_result}

func restore(data:Dictionary) -> bool:
 if not data.get("phase","") in ["draft","serve","receipt","upgrade","lost","won"]: return false
 for key in ["board","stock","enhancements","offers","ledger"]:
  if not data.get(key) is Array: return false
 for key in ["coins","day","order"]:
  if not (data.get(key) is float or data.get(key) is int): return false
  if float(data[key])!=int(data[key]): return false
 if not data.get("last_result") is Dictionary: return false
 if data.board.size()!=9 or data.stock.size()!=12 or data.enhancements.size()!=12 or data.offers.size()!=3: return false
 if int(data.day)<1 or int(data.day)>3 or int(data.order)<0 or int(data.order)>9: return false
 if abs(data.coins)>1000000: return false
 for id in data.board:
  if not (id is float or id is int) or id<-1 or id>11 or float(id)!=int(id): return false
 for id in data.offers:
  if not (id is float or id is int) or id<6 or id>11 or float(id)!=int(id): return false
 for n in data.stock+data.enhancements:
  if not (n is float or n is int) or n<0 or n>99 or float(n)!=int(n): return false
 for n in data.ledger:
  if not (n is float or n is int): return false
 var expected_day=mini(3,int(data.order)/3+1)
 if data.phase in ["upgrade","lost","won"]:
  if int(data.order)%3!=0 or int(data.order)==0 or int(data.day)!=int(data.order)/3: return false
 elif int(data.day)!=expected_day or int(data.order)>=9: return false
 if data.phase=="won" and (int(data.order)!=9 or data.coins<0): return false
 if data.phase=="upgrade" and (int(data.day)>=3 or data.coins<0): return false
 if data.phase=="lost" and data.coins>=0: return false
 if data.phase in ["receipt","upgrade","lost","won"]:
  for key in ["total","cost","profit"]:
   if not (data.last_result.get(key) is float or data.last_result.get(key) is int): return false
 day=int(data.day); order=int(data.order); coins=int(data.coins)
 board=data.board.duplicate(); stock=data.stock.duplicate(); enhancements=data.enhancements.duplicate(); phase=data.phase
 offers=data.offers.duplicate(); ledger=data.ledger.duplicate(); last_result=data.last_result.duplicate()
 return true
