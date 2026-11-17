$input a_position
#ifdef INSTANCING
$input i_data0, i_data1, i_data2, i_data3
#endif
$output v_posTime

#include <bgfx_shader.sh>

void main() {
#ifdef INSTANCING
    mat4 model = mtxFromCols(i_data0, i_data1, i_data2, i_data3);
#else
    mat4 model = u_model[0];
#endif
    vec3 pos = mul(model, vec4(a_position, 1.0)).xyz;
    v_posTime = vec4(pos, 0.0);
    gl_Position = mul(u_viewProj, vec4(pos, 1.0));
}
