$input a_color0, a_position, a_texcoord0
#ifdef INSTANCING
    $input i_data1, i_data2, i_data3
#endif

$output v_color0, v_texcoord0, v_worldPos

#include <bgfx_shader.sh>

void main() {
    v_color0 = vec4_splat(0.0);
    v_texcoord0 = vec2_splat(0.0);
    v_worldPos = vec3_splat(0.0);
    gl_Position = vec4_splat(0.0);
}
