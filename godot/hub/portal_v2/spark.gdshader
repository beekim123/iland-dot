shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 tone : source_color = vec4(1.0,.5,.8,1.0);
void fragment(){vec2 p=abs((UV-.5)*2.0);float dot_light=exp(-length(p)*7.0);float cross_light=exp(-min(p.x,p.y)*28.0)*exp(-max(p.x,p.y)*5.0);ALBEDO=mix(tone.rgb,vec3(1),.5);ALPHA=dot_light+cross_light*.6;}
