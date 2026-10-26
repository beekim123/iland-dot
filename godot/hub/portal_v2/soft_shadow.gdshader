shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
void fragment(){float r=length((UV-.5)*2.0);ALBEDO=vec3(.16,.12,.22); ALPHA=(1.0-smoothstep(.05,1.0,r))*.23;}
