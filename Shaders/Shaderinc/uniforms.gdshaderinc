#ifndef UNIFORMS_INCLUDED
#define UNIFORMS_INCLUDED

#include "constants.gdshaderinc"

// Material properties
group_uniforms Shader_Properties;
uniform vec3 surface_color : source_color = vec3(1.0);
uniform vec3 ambient_color : source_color = vec3(0.0); // Local color
uniform float ambient_strength : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;
uniform float terminator_offset : hint_range(0.0, 1.0) = 0.0;
uniform float Local_Ambient_Influence : hint_range(0.0, 1.0) = 0.0; // 0 = world, 1 = local

// Specular properties
group_uniforms Specular_Properties;
uniform bool enable_specular = false;
uniform bool per_pixel_specular = true;
uniform vec3 specular_color : source_color = vec3(1.0);
uniform float specular_power : hint_range(1.0, 256.0) = 32.0;
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.5;

// Light properties
group_uniforms Debug_Properties;
uniform vec3 world_ambient_color : source_color = vec3(0.0); // Set from script
uniform int active_light_count;
uniform vec3 light_directions[MAX_LIGHTS];
uniform vec3 light_positions[MAX_LIGHTS];
uniform vec3 light_colors[MAX_LIGHTS];
uniform float light_intensities[MAX_LIGHTS];
uniform bool is_point_light[MAX_LIGHTS];
uniform float light_ranges[MAX_LIGHTS];
uniform float light_attenuations[MAX_LIGHTS];

#endif