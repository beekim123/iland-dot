"""Read-only numerical sampling of common animate_gardener paw/grip contact.
This is an analytic geometry check, not a substitute for runtime animation QA.
"""
import json, math
from pathlib import Path
HERE=Path(__file__).resolve().parent

def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def rx(p,a):return p[0],p[1]*math.cos(a)-p[2]*math.sin(a),p[1]*math.sin(a)+p[2]*math.cos(a)
def distance(a,b):return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))
shoulder=(.257,.875,-.005);fore=(.028,-.132,-.028);palm=(0,-.069,-.015)
weapon=(.31,.60923076923,-.29);muzzle=(0,.04,-.51)
idle_paw=add(shoulder,rx(add(fore,rx(palm,.70)),.50));grip=sub(idle_paw,weapon)
checks=[]
for speed in (0,.5,1):
    for shoot in (False,True):
        for dash in (False,True):
            worst=(0,0)
            for i in range(6001):
                t=i*.005;gait=math.sin(t*(17 if dash else 10.4))*speed
                bob=abs(math.cos(t*(17 if dash else 10.4)))*.026*speed+math.sin(t*2.2)*.004*(1-speed)
                armangle=.50+gait*.05+(abs(math.sin(t*38))*.04 if shoot else 0)
                paw=add(add(shoulder,(0,bob,0)),rx(add(fore,rx(palm,.70)),armangle))
                wa=-abs(math.sin(t*38))*.065 if shoot else math.sin(t*3.2)*.012
                actual_grip=add(add(weapon,muzzle),rx(sub(grip,muzzle),wa))
                error=distance(paw,actual_grip)
                if error>worst[0]:worst=error,t
            checks.append({'speed':speed,'shooting':shoot,'dash':dash,'maximum_center_distance_m':worst[0],'at_seconds':worst[1]})
maximum=max(c['maximum_center_distance_m'] for c in checks)
# The soft paw radius is at least .083m; center separation is conservatively smaller.
assert maximum<.083,maximum
report={'status':'PASS','sample_count':len(checks)*6001,'time_range_seconds':[0,30],'sample_step_seconds':.005,'max_observed_center_distance_m':maximum,'max_observed_distance_after_runtime_scale_1_3_m':maximum*1.3,'conservative_paw_radius_m':.083,'checks':checks,'scope':'Read-only analytical common animation sampling; not full-game runtime validation.'}
(HERE/'grip_envelope_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
