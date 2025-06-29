shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

#include "res://Shaders/Shaderinc/constants.gdshaderinc"
#include "res://Shaders/Shaderinc/uniforms.gdshaderinc"
#include "res://Shaders/Shaderinc/varyings.gdshaderinc"
#include "res://Shaders/Shaderinc/lighting_functions.gdshaderinc"

void vertex() {
    vertex_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vertex_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Blend between world and local ambient color
    vec3 effective_ambient = mix(world_ambient_color, ambient_color, Local_Ambient_Influence);

    vec3 total_lighting = effective_ambient * ambient_strength;
    vec3 total_specular = vec3(0.0);
    
    // Calculate view direction if we need per-vertex specular
    vec3 view_dir;
    if (enable_specular && !per_pixel_specular) {
        vec3 camera_pos = (inverse(VIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        view_dir = normalize(camera_pos - vertex_world_position);
    }
    
    for (int i = 0; i < min(active_light_count, MAX_LIGHTS); i++) {
        vec3 light_dir;
        float attenuation = 1.0;
        
        if (is_point_light[i]) {
            vec3 to_light = light_positions[i] - vertex_world_position;
            float distance = length(to_light);
            light_dir = normalize(to_light);
            attenuation = calc_attenuation(distance, light_ranges[i], light_attenuations[i]);
        } else {
            light_dir = normalize(-light_directions[i]);
        }
        
        float diffuse_factor = calc_diffuse(vertex_world_normal, light_dir, terminator_offset);
        vec3 diffuse = diffuse_factor * light_colors[i] * light_intensities[i];
        
        vec3 soft_diffuse = light_colors[i] * light_intensities[i] * 0.1;
        diffuse = mix(diffuse, soft_diffuse, roughness * 0.3);
        
        // Calculate per-vertex specular if enabled
        if (enable_specular && !per_pixel_specular) {
            total_specular += calc_specular_light(vertex_world_normal, light_dir, view_dir, 
                                                light_colors[i], light_intensities[i], attenuation);
        }
        
        total_lighting += diffuse * attenuation;
    }
    
    final_lighting = total_lighting;
    vertex_specular = total_specular;
}

void fragment() {
    vec3 total_specular = vec3(0.0);
    
    if (enable_specular) {
        if (per_pixel_specular) {
            // Per-pixel specular calculation
            vec3 camera_pos = (inverse(VIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
            vec3 view_dir = normalize(camera_pos - vertex_world_position);
            vec3 normal = normalize(vertex_world_normal);
            
            for (int i = 0; i < min(active_light_count, MAX_LIGHTS); i++) {
                vec3 light_dir;
                float attenuation = 1.0;
                
                if (is_point_light[i]) {
                    vec3 to_light = light_positions[i] - vertex_world_position;
                    float distance = length(to_light);
                    light_dir = normalize(to_light);
                    attenuation = calc_attenuation(distance, light_ranges[i], light_attenuations[i]);
                } else {
                    light_dir = normalize(-light_directions[i]);
                }
                
                total_specular += calc_specular_light(normal, light_dir, view_dir, 
                                                    light_colors[i], light_intensities[i], attenuation);
            }
        } else {
            // Use pre-calculated per-vertex specular
            total_specular = vertex_specular;
        }
    }
    
    ALBEDO = (final_lighting + total_specular) * surface_color;
}