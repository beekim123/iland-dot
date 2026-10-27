shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The simulation ownership mask is the sole source of coverage.
// Bilinear half-coverage contours + one-screen-pixel AA soften ONLY subtexel edges.
// Every authoritative texel center retains its team; no blurred mixed third color.
uniform sampler2D coverage_map : filter_linear, repeat_disable;
uniform vec2 grid_size = vec2(384.0, 288.0);
uniform vec2 world_size = vec2(32.0, 24.0);
uniform vec4 mineral_a : source_color = vec4(0.8627,0.8824,0.8824,1.0);
uniform vec4 mineral_b : source_color = vec4(0.8275,0.8510,0.8549,1.0);
uniform vec4 blue_glint : source_color = vec4(0.8627,0.9098,1.0,1.0);
uniform vec4 orange_glint : source_color = vec4(1.0,0.9412,0.8549,1.0);
uniform vec4 blue_liquid : source_color = vec4(0.1843,0.3843,1.0,1.0);
uniform vec4 orange_liquid : source_color = vec4(1.0,0.5412,0.1216,1.0);
uniform float liquid_time = 0.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float grain(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
float mineral_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p); t = t*t*(3.0-2.0*t);
	return mix(mix(grain(cell),grain(cell+vec2(1.0,0.0)),t.x),
		mix(grain(cell+vec2(0.0,1.0)),grain(cell+vec2(1.0,1.0)),t.x),t.y);
}
void fragment() {
	vec2 texel = 1.0 / grid_size;
	vec2 center_uv = (floor(UV * grid_size) + vec2(0.5)) * texel;
	vec2 coverage = texture(coverage_map, UV).rg;
	float occupancy = min(1.0, coverage.r + coverage.g);
	float aa = min(.20,max(fwidth(occupancy)*.72,.002));
	float owned = smoothstep(.5-aa,.5+aa,occupancy);
	vec2 owner = coverage.r >= coverage.g ? vec2(1.0,0.0) : vec2(0.0,1.0);
	vec2 p = UV * world_size;
	// Continuous low-frequency stone variation is faded before undersampling.
	// Avoid a raw hash at 42 samples/m that can undersample on software GL.
	vec2 stone_uv = p*2.4;
	float detail = 1.0-smoothstep(.22,.65,max(length(dFdx(stone_uv)),length(dFdy(stone_uv))));
	float micro = mix(.5,mineral_noise(stone_uv),detail);
	vec3 mineral = mix(mineral_a.rgb,mineral_b.rgb,micro*.28);
	float flow = sin(p.x*1.9 + sin(p.y*2.3)*0.48) * sin(p.y*2.8 - p.x*0.42);
	vec3 paint = blue_liquid.rgb*owner.r + orange_liquid.rgb*owner.g;
	paint *= 0.97 + flow*0.035;
	vec2 l = texture(coverage_map, center_uv-vec2(texel.x,0.0)).rg;
	vec2 r = texture(coverage_map, center_uv+vec2(texel.x,0.0)).rg;
	vec2 t = texture(coverage_map, center_uv-vec2(0.0,texel.y)).rg;
	vec2 b = texture(coverage_map, center_uv+vec2(0.0,texel.y)).rg;
	// The raised meniscus changes light/normal strictly INSIDE the owned mask.
	vec2 slope = vec2(dot(owner,l)-dot(owner,r),dot(owner,t)-dot(owner,b));
	vec2 waves = vec2(cos(p.x*6.2+sin(p.y*4.3)*.8+liquid_time*.34),sin(p.y*5.1-p.x*2.1+sin(p.x*3.8)*.7-liquid_time*.30));
	vec2 bump = (waves*.065+slope*.22)*owned;
	NORMAL_MAP = vec3(bump*.5+vec2(.5),1.0);
	NORMAL_MAP_DEPTH = .8;
	vec3 view_world = normalize(CAMERA_POSITION_WORLD-world_position);
	vec3 wet_normal = normalize(vec3(bump.x,1.0,bump.y));
	vec3 reflection = reflect(-view_world,wet_normal);
	float grazing = pow(1.0-max(dot(view_world,wet_normal),0.0),4.0);
	// Broken, narrow sky sheen adds readable viscosity without whitening ownership.
	float sky_band = smoothstep(.14,.17,reflection.y)*(1.0-smoothstep(.21,.27,reflection.y));
	float cloud_break = pow(.5+.5*sin(reflection.x*17.0+reflection.z*11.0),8.0);
	float wet_glint = sky_band*(.12+.88*cloud_break)*.14+grazing*.018;
	vec3 pearl = mix(blue_glint.rgb,orange_glint.rgb,owner.g);
	paint = mix(paint,pearl,wet_glint);
	ALBEDO = mix(mineral,paint,owned);
	ROUGHNESS = mix(.90,.20+.025*flow,owned);
	SPECULAR = mix(.16,.52,owned);
	METALLIC = 0.0;
	EMISSION = paint*.016*owned;
}
