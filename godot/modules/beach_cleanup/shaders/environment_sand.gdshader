shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 sand_color : source_color = vec4(0.76, 0.63, 0.43, 1.0);
uniform float grain_strength = 0.025;
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7)))*43758.5453); }
void fragment() {
 float grain = hash(floor(local_pos*75.0));
 float band = sin(local_pos.y*32.0 + sin(local_pos.x*0.9)*0.8)*0.012;
 ALBEDO = sand_color.rgb * COLOR.rgb * (0.97 + grain_strength*grain + band);
 ROUGHNESS = 0.96;
}
