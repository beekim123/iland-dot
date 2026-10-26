shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float water_time = 0.0;
uniform bool seabed = false;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
// Radius samples come from the approved v3 terrain's exact calm-water shoreline.
uniform sampler2D shore_radii : filter_linear, repeat_enable;
float shore_radius(float angle) {
 float u=fract(angle/6.28318530718);
 vec2 rg=texture(shore_radii,vec2(u+0.5/256.0,0.5)).rg;
 return (rg.r*65280.0+rg.g*255.0)/65535.0*16.0;
}
float coast(vec2 p) {
 // Godot Z is the negative of Blender Y. Center is Blender (0,1.1).
 vec2 q=vec2(p.x,-p.y-1.1);
 float a=atan(q.y,q.x);
 float radius=shore_radius(a);
 // Avoid finite-difference derivatives of packed texture channels on GLES.
 // They amplify quantization into radial streaks far from the island.
 // The zero contour remains the exact approved dry shoreline.
 return length(q)-radius;
}
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 if (!seabed) {
  vec2 p=world_position.xz;
  float h=0.052*sin(p.x*0.81+p.y*0.38-water_time*1.12)+0.025*sin(p.x*1.43-p.y*0.91+water_time*1.67);
  VERTEX.y+=h;
  world_position.y+=h;
 }
}
void fragment() {
 vec2 p=world_position.xz;
 float r=coast(p);
 float depth=smoothstep(0.2,14.0,r);
 float n=noise(p*0.72+vec2(water_time*0.09,-water_time*0.07));
 float w1=sin(p.x*0.81+p.y*0.38-water_time*1.12);
 float w2=sin(p.x*1.43-p.y*0.91+water_time*1.67);
 if(seabed) {
  vec3 sand=mix(vec3(0.47,0.73,0.59),vec3(0.055,0.30,0.36),smoothstep(0.0,15.0,r));
  float c=sin(p.x*2.4+p.y*1.2+water_time*0.68+noise(p*0.8)*3.0)*sin(p.y*2.6-p.x*0.8-water_time*0.54);
  float caustic=pow(abs(c),12.0)*(1.0-smoothstep(4.0,13.0,r));
  ALBEDO=sand+vec3(0.09,0.13,0.10)*caustic;
  ALPHA=1.0;
 } else {
  vec3 tint=mix(vec3(0.19,0.71,0.67),vec3(0.035,0.34,0.43),depth);
  tint+=(w1*0.025+w2*0.015+n*0.025);
  // Thin, directionally coherent moving glints, not a noisy full-screen texture.
  float crest=pow(max(0.0,0.55*w1+0.45*w2),20.0);
  float spark=crest*smoothstep(0.30,0.75,n)*0.09;
  // Travel inward from the turquoise shallows onto the beach's waterline.
  float phase=fract(water_time/6.5);
  float wave_radius=1.7-phase*1.55;
  float broken=0.4+0.6*smoothstep(0.25,0.75,noise(p*1.9+vec2(water_time*.14)));
  float ring=exp(-pow((r-wave_radius)/0.075,2.0));
  float ring2=exp(-pow((r-(wave_radius+0.72))/0.055,2.0))*0.45;
  float shoreline=exp(-pow((r-0.10-0.08*sin(water_time*.7))/0.13,2.0))*0.33;
  float foam=clamp((ring+ring2)*broken*sin(phase*3.14159265)+shoreline*broken,0.0,0.9);
  ALBEDO=mix(tint+vec3(spark),vec3(0.84,0.96,0.90),foam);
  ALPHA=clamp(mix(0.27,0.83,depth)+foam*0.67,0.0,0.94);
 }
}
