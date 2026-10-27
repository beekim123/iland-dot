shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

// Original analytic watercolor: broad pigment pools and fixed paper tooth.
// No time-based grain and no downloaded/raster source textures.
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 wash_color : source_color = vec4(0.94, 0.92, 0.80, 1.0);
uniform float wash_strength : hint_range(0.0, 1.0) = 0.12;
uniform float paper_strength : hint_range(0.0, 0.2) = 0.033;
uniform float pigment_strength : hint_range(0.0, 0.3) = 0.075;
uniform float edge_darkening : hint_range(0.0, 0.3) = 0.055;
uniform bool use_vertex_color = true;
varying vec3 paint_position;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float paper_noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.,0.)), f.x),
               mix(hash21(i + vec2(0.,1.)), hash21(i + vec2(1.,1.)), f.x), f.y);
}
void vertex() { paint_position = VERTEX; }
void fragment() {
    vec3 pigment = base_color.rgb * (use_vertex_color ? COLOR.rgb : vec3(1.));
    vec2 brush = paint_position.xy * vec2(13.1, 18.3) + paint_position.z * 6.1;
    float pools = paper_noise(brush * .31) * .66 + paper_noise(brush * .89) * .34;
    float dry_edges = smoothstep(.42, .60, pools) - smoothstep(.62, .81, pools);
    // Fixed screen paper at a broad enough scale to avoid subpixel sparkle.
    float grain = paper_noise(FRAGCOORD.xy / 2.8) - .5;
    float grazing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
    vec3 watered = mix(pigment, wash_color.rgb, wash_strength * (.4 + .6 * pools));
    watered *= 1.0 - pigment_strength * dry_edges - edge_darkening * grazing;
    ALBEDO = clamp(watered + grain * paper_strength, vec3(.025), vec3(1.));
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    SPECULAR = 0.0;
}
void light() {
    float wrap = clamp((dot(NORMAL, LIGHT) + .45) / 1.45, 0.0, 1.0);
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * wrap * ATTENUATION;
}
