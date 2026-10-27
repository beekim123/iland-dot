shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Opaque pigmented liquid: a saturated body and narrow white sunlight glints.
// Never transparent glass, additive neon or a pale row of separate marbles.
uniform vec4 nectar_color : source_color = vec4(0.1843,0.3843,1.0,1.0);
uniform vec4 foam_color : source_color = vec4(0.8627,0.9098,1.0,1.0);
void fragment() {
	float capillary = 1.0-COLOR.r;
	float pearl = pow(max(dot(normalize(NORMAL), normalize(VIEW + vec3(-0.45,0.75,0.0))),0.0), 64.0);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 5.0);
	float sheen = min(0.34, rim*0.055 + pearl*0.26 + capillary*0.22);
	ALBEDO = mix(nectar_color.rgb,foam_color.rgb,sheen);
	METALLIC = 0.0;
	SPECULAR = 0.62;
	ROUGHNESS = 0.17;
	// Only a tiny body lift: ordinary sun/shadow still controls the liquid volume.
	EMISSION = nectar_color.rgb*0.018 + foam_color.rgb*capillary*0.018;
}
