shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// Global light direction from project settings
uniform vec3 light_direction;

// Color uniforms
uniform vec3 surface_color : source_color = vec3(1.0);
uniform vec3 light_color : source_color = vec3(1.0);
uniform vec3 ambient_color : source_color = vec3(0.0);

// Lighting parameters
uniform float light_intensity : hint_range(0.0, 5.0) = 1.0;
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;
uniform float terminator_offset : hint_range(0.0, 1.0) = 0.0;

varying vec3 final_lighting;

void vertex() {
    // Transform to world space
    vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    
    // Normalize light direction (directional light)
    vec3 light_dir = normalize(-light_direction);
    
    // Ambient component
    vec3 ambient = ambient_strength * ambient_color;
    
    // Diffuse component with terminator offset
    float ndotl = dot(world_normal, light_dir);
    float biased_ndotl = clamp(ndotl + terminator_offset, 0.0, 1.0);
    vec3 diffuse = biased_ndotl * light_color * light_intensity;
    
    // Apply roughness softening
    vec3 soft_diffuse = light_color * light_intensity * 0.1;
    diffuse = mix(diffuse, soft_diffuse, roughness * 0.3);
    
    // No distance attenuation for directional light
    
    // Combine lighting components
    final_lighting = ambient + diffuse;
}

void fragment() {
    ALBEDO = final_lighting * surface_color;
}