shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

const int MAX_LIGHTS = 9;

// Array of light directions
uniform vec3 light_directions[MAX_LIGHTS];

// Array of light colors
uniform vec3 light_colors[MAX_LIGHTS];

// Array of light intensities
uniform float light_intensities[MAX_LIGHTS];

// Number of active lights
uniform int active_light_count;

// Other uniforms remain the same
uniform vec3 surface_color : source_color = vec3(1.0);
uniform vec3 ambient_color : source_color = vec3(0.0);
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;
uniform float terminator_offset : hint_range(0.0, 1.0) = 0.0;

varying vec3 final_lighting;

void vertex() {
    // Transform to world space
    vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    
    // Initialize lighting
    vec3 total_lighting = ambient_strength * ambient_color;
    
    // Process each light
    for(int i = 0; i < MAX_LIGHTS; i++) {
        if(i >= active_light_count) break;
        
        vec3 light_dir = normalize(-light_directions[i]);
        
        // Diffuse component with terminator offset
        float ndotl = dot(world_normal, light_dir);
        float biased_ndotl = clamp(ndotl + terminator_offset, 0.0, 1.0);
        vec3 diffuse = biased_ndotl * light_colors[i] * light_intensities[i];
        
        // Apply roughness softening
        vec3 soft_diffuse = light_colors[i] * light_intensities[i] * 0.1;
        diffuse = mix(diffuse, soft_diffuse, roughness * 0.3);
        
        total_lighting += diffuse;
    }
    
    final_lighting = total_lighting;
}

void fragment() {
    ALBEDO = final_lighting * surface_color;
}