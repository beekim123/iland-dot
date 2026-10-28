# Dawn Sword runtime / handdrawn contract v1

Pure 2D, 1280×800 reference viewport. World x right, y down. All actor coordinates are feet, art origin bottom center. Hero collision width 32 height 70; render height 112 (atlas transparent padding permitted). Enemies render 96–144, bosses 210, dragon 330. Camera follows horizontal world coordinates; ground nominal y=620. No runtime polygons are accepted as final character art.

`art/manifest.json`: {"actors":{"hero":{"file":"hero.png","columns":8,"rows":N,"frame_width":256,"frame_height":256,"height":112,"animations":{"idle":{"row":0,"frames":4,"fps":8,"loop":true},"run":...}}},"backgrounds":["chapter1.png",...],"props":{...}}
Files relative to art/. Optional per-animation `file`, `columns`, `row`, `start`, `frames`, `fps`, `loop`. Optional actor `anchor` [0.5,1.0]. Each frame uniformly packed; actual unique handdrawn movement frames required, not transformed stills. Renderer uses animation name and elapsed action time, flips left facing. Art does not drive collision.

Hero animation names: idle, run, jump, fall, land, attack1, attack2, attack3, air_attack, roll, guard, parry, hurt, heal, dawn, climb, death, interact. Prioritize idle/run/3 attacks/jump/roll/guard/hurt/death. Enemy actor IDs bandit,wolf,shield,archer,bat,salamander,slinger,heavy,mage; actions idle/run/windup/attack/hurt/death. Boss IDs axe_lord,bridge_guard,rock_lizard,ash_knight,dragon; additionally dragon fly/breath/stagger. Princess idle/interact/run/rescued. Missing animation falls back visibly and is reported as incomplete, never marked accepted.

Rules snapshot fields: chapter 0..4, segment 0..3, level {name,width,platforms,hazards,ladder,objective}, hero {x,y,vx,vy,facing,hp,max_hp,animation,anim_time,grounded,guard,charge,heals}, enemies [{id,kind,x,y,hp,max_hp,facing,state,timer,animation,anim_time,boss,phase}], projectiles, effects, flags, story, mode, time. State damage events feed runtime audio; sprites are actual PNG atlas regions. All gameplay runs fixed 1/60 rules step from abstract input held/pressed dictionary.

Art worker owns art/ only; implementation worker integrates manifest dynamically. Main UI parchment/ink borders drawn as UI primitives with readable font, not soft gummy styling. Background chapter layers may be manifest objects {far,mid,near}, each transparent PNG; support flat paths initially.
