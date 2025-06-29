#ifndef LIGHTING_FUNCTIONS_INCLUDED
#define LIGHTING_FUNCTIONS_INCLUDED

#include "uniforms.gdshaderinc"

float calc_diffuse(vec3 world_normal, vec3 light_dir, float offset) {
    float ndotl = dot(world_normal, light_dir);
    return clamp(ndotl + offset, 0.0, 1.0);
}

float calc_attenuation(float distance, float range, float attenuation) {
    float normalized_dist = distance / range;
    float inv_square = 1.0 / (1.0 + attenuation * normalized_dist * normalized_dist);
    float range_falloff = 1.0 - smoothstep(0.8, 1.0, normalized_dist);
    return inv_square * range_falloff;
}

vec3 calc_specular_light(vec3 normal, vec3 light_dir, vec3 view_dir, vec3 light_color, float light_intensity, float attenuation) {
    vec3 reflect_dir = reflect(-light_dir, normal);
    float spec = pow(max(dot(view_dir, reflect_dir), 0.0), specular_power);
    return spec * specular_color * light_intensity * specular_intensity * attenuation;
}

#endif