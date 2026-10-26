shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 tone : source_color = vec4(0.98,0.18,0.56,1.0);
uniform float phase = 0.0;
uniform float strength = 1.0;
uniform float layer = 0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*0.58+noise(p*2.03+8.0)*0.28+noise(p*4.09)*0.14;}
void fragment(){
 vec2 p=(UV-0.5)*2.0; float t=phase;
 float a=atan(p.y,p.x); float r=length(p);
 float edge=0.765+0.045*sin(a*3.0+t*.55)+0.038*sin(a*5.0-t*.72)+0.022*sin(a*9.0+t*.43);
 edge+=0.026*sin(p.y*16.0+t*1.8)*sin(a*2.0+1.0);
 float d=r-edge;
 float inside=1.0-smoothstep(-0.025,0.025,d);
 float rim=exp(-abs(d)*65.0);
 float halo=exp(-abs(d)*15.0);
 vec2 q=p+VIEW.xy*0.07;
 float cloud=fbm(q*3.0+vec2(sin(t*.31),-t*.27));
 float field=fbm(q*4.7+vec2(cloud*1.5,t*.18));
 float ribbon=pow(max(0.0,sin(q.y*14.0+sin(q.x*5.2+t*.55)*2.5+field*5.0-t*1.6)),12.0);
 float ribbon2=pow(max(0.0,sin(q.x*17.0+q.y*8.0+cloud*8.0+t*.9)),20.0);
 float depth=exp(-length(q-vec2(.11,-.06))*3.0);
 vec3 dark=tone.rgb*vec3(.21,.13,.32)+vec3(.035,.018,.085);
 vec3 col=mix(dark,tone.rgb,cloud*.72);
 col=mix(col,tone.rgb*.55+vec3(.40,.45,.52),ribbon*.45+ribbon2*.12);
 col*=1.0-depth*.4;
 col+=tone.rgb*halo*.52+mix(tone.rgb,vec3(1.0),.78)*rim*1.3;
 float alpha=inside*(.65+cloud*.21)+halo*.38;
 if(layer>0.5){col=mix(tone.rgb,vec3(1),.38);alpha=(halo*.12+rim*.15)*strength;}
 ALBEDO=col*strength; ALPHA=clamp(alpha,0.0,.96);
}
