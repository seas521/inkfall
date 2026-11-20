extends SceneTree
const Solver=preload("res://scripts/chapters/mine_contact_solver.gd")
var failed:=false
var assertions:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 assertions+=1
 if not ok:failed=true;push_error(message)
func rail(x:float,speed:float,mass:float=220.,fixed:bool=false)->Dictionary:
 return {"motion":&"rail","origin":Vector2(x,0),"axis":Vector2.RIGHT,"rotation":0.,"offset":Vector2(0,-25),"half":Vector2(31,22),"buffer_offset":Vector2(0,-23),"buffer_half":Vector2(36.5,6),"q":0.,"speed":speed,"inv":0. if fixed else 1./mass,"fixed":fixed,"mass":mass}
func hinge(angle:float,speed:float)->Dictionary:
 return {"motion":&"hinge","origin":Vector2(0,-504),"length":470.,"offset":Vector2(0,3),"half":Vector2(32,31),"q":angle,"speed":speed,"inv":1./(8000.*473.*473.),"fixed":false}
func energy(bodies:Array)->float:
 var out:=0.
 for body in bodies:
  if body.inv>0:out+=.5*float(body.speed)*float(body.speed)/float(body.inv)
 return out
func momentum(bodies:Array)->float:
 var out:=0.
 for body in bodies:
  if body.inv>0:out+=float(body.speed)/float(body.inv)
 return out
func buffer_pair(a:int=0,b:int=1)->Dictionary:
 return {"a":a,"b":b,"shape_a":"buffer","shape_b":"buffer","material":&"buffer","restitution":.72}
func pair_check(u:float,v:float,m1:float,m2:float)->void:
 var bodies:Array=[rail(0,u,m1),rail(73,v,m2)]
 var solver:=Solver.new();var before:=energy(bodies);var p:=momentum(bodies)
 solver.step(bodies,[buffer_pair()],1./120)
 check(absf(momentum(bodies)-p)<.00001*maxf(1,absf(p)),"pair impulse must conserve momentum")
 check(energy(bodies)<=before*1.00001+.0001,"passive impact cannot create kinetic energy")
 var expected_a:=((m1-.72*m2)*u+1.72*m2*v)/(m1+m2)
 var expected_b:=((m2-.72*m1)*v+1.72*m1*u)/(m1+m2)
 check(absf(float(bodies[0].speed)-expected_a)<.002 and absf(float(bodies[1].speed)-expected_b)<.002,"either approach direction must match the same analytic impact")
 var reversed:Array=[rail(73,v,m2),rail(0,u,m1)]
 Solver.new().step(reversed,[buffer_pair()],1./120)
 check(absf(float(reversed[1].speed)-float(bodies[0].speed))<.002 and absf(float(reversed[0].speed)-float(bodies[1].speed))<.002,"swapping object IDs cannot change the impact")
func run()->void:
 for values in [[600.,0.,220.,220.],[0.,-600.,220.,220.],[200.,-300.,300.,220.],[-100.,-700.,220.,300.],[550.,250.,380.,220.]]:
  pair_check(values[0],values[1],values[2],values[3])
 var co:Array=[rail(0,100),rail(73,100)]
 var same:=Solver.new()
 var same_events:=0
 for i in 120:same_events+=same.step(co,[buffer_pair()],1./120).size()
 check(same_events==0 and co[0].speed==100. and co[1].speed==100.,"co-moving contact cannot keep firing impacts")
 var apart:Array=[rail(0,-100),rail(73,100)]
 check(Solver.new().step(apart,[buffer_pair()],1./60).is_empty(),"separating bodies cannot attract or receive another bounce")
 var fast:Array=[rail(0,5000),rail(160,0)]
 var fast_events:=Solver.new().step(fast,[buffer_pair()],1./30)
 check(not fast_events.is_empty() and fast[1].speed>1000,"adaptive travel must catch a fast crossing")
 check(float(fast[1].origin.x)+float(fast[1].q)>float(fast[0].origin.x)+float(fast[0].q),"fast collision cannot swap body order")
 # Mirror a pivot / rail contact. No side or roof special-case is supplied.
 for angle in [.12,.45,.50]:
  var positive:Array=[hinge(angle,-1.2),rail(470*sin(angle)+12,0)]
  var negative:Array=[hinge(-angle,1.2),rail(-470*sin(angle)-12,0)]
  var sa:=Solver.new();var sb:=Solver.new()
  var before:=energy(positive)
  var ea:=sa.step(positive,[{"a":0,"b":1,"material":&"iron"}],1./120)
  var eb:=sb.step(negative,[{"a":0,"b":1,"material":&"iron"}],1./120)
  check(not sa.last_contacts.is_empty() and not sb.last_contacts.is_empty(),"mirror cases must exercise actual contact at angle "+str(angle))
  check(absf(float(positive[0].speed)+float(negative[0].speed))<.002,"hinge response must mirror across left/right")
  check(absf(float(positive[1].speed)+float(negative[1].speed))<.002,"cart response must mirror across left/right")
  check(energy(positive)<=before*1.00001+.001,"constrained roof/corner contact cannot create energy")
 # Three contacts are solved together rather than overwritten later.
 var chain:Array=[rail(0,900),rail(73,0,300),rail(146,0)]
 var initial:=energy(chain);var mp:=momentum(chain)
 var sc:=Solver.new();sc.step(chain,[buffer_pair(0,1),buffer_pair(1,2)],1./120)
 check(energy(chain)<=initial*1.00001,"contact chain must remain passive")
 check(absf(momentum(chain)-mp)<.01,"contact chain must conserve total momentum")
 var duplicate:=chain.duplicate(true)
 for i in 60:sc.step(duplicate,[buffer_pair(0,1),buffer_pair(1,2)],1./120)
 check(energy(duplicate)<=initial*1.00001,"sustained multi-contact cannot pump energy")
 var locked:Array=[rail(0,400),rail(73,0,220,true)]
 Solver.new().step(locked,[buffer_pair()],1./120)
 check(locked[1].q==0 and locked[1].speed==0 and locked[0].speed<0,"a locked constraint must react through the same solver")
 # Frame-rate variation must not change the impulse law.
 var rate_results:Array=[]
 for hz in [30,60,120]:
  var sample:Array=[rail(0,600),rail(160,0,300)]
  var state:=Solver.new()
  for i in hz:state.step(sample,[buffer_pair()],1./float(hz))
  rate_results.append(Vector2(sample[0].speed,sample[1].speed))
 check(rate_results[0].distance_to(rate_results[1])<.01 and rate_results[1].distance_to(rate_results[2])<.01,"30/60/120 Hz must use the same impact law")
 var mover:=rail(0,0)
 var obstacles:Array=[{"body":rail(90,0),"self_shape":"buffer","other_shape":"buffer"}]
 var accepted:=Solver.limit_translation(mover,obstacles,50.)
 check(accepted>14 and accepted<=17.01,"manual sweep must use actual buffer geometry")
 mover.origin=Vector2(20,0)
 check(Solver.limit_translation(mover,obstacles,-20.)== -20.,"a separating manual move must remain possible")
 check(Solver.limit_translation(mover,obstacles,10.)==0.,"manual input cannot deepen existing penetration")
 var resting_results:Array=[]
 for side in [-1.,1.]:
  var sample:Array=[rail(-100*side,500*side),hinge(0,0)]
  var ek:=energy(sample);var state:=Solver.new();var impacts:=0
  for i in 30:impacts+=state.step(sample,[{"a":0,"b":1,"material":&"iron"}],1./120).size()
  check(impacts>0 and float(sample[1].speed)*side>0,"a cart must be able to drive a resting free hinge")
  check(energy(sample)<=ek*1.00002,"reverse initiation must remain passive")
  resting_results.append(Vector2(sample[0].speed,sample[1].speed))
 check((resting_results[0]+resting_results[1]).length()<.01,"reverse initiation must mirror")
 var random:=RandomNumberGenerator.new();random.seed=17001
 for sample_id in 200:
  var sample:Array=[rail(0,random.randf_range(-800,800),random.randf_range(100,600)),rail(73,random.randf_range(-800,800),random.randf_range(100,600)),rail(146,random.randf_range(-800,800),random.randf_range(100,600))]
  var pairs:Array=[buffer_pair(0,1),buffer_pair(1,2)]
  pairs[0].restitution=random.randf_range(.28,.72);pairs[1].restitution=random.randf_range(.28,.72)
  var ek:=energy(sample);var total:=momentum(sample)
  Solver.new().step(sample,pairs,1./120)
  check(energy(sample)<=ek*1.00002+.01,"random multi-contact must not create energy: "+str(sample_id))
  check(absf(momentum(sample)-total)<.01,"random multi-contact must conserve momentum")
 print("MINE CONTACT SOLVER V17 ","FAIL" if failed else "PASS"," assertions=",assertions)
 quit(1 if failed else 0)
