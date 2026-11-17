$input v_clipPosition, v_worldPosition, v_color0, v_ditheringAndMaskTinting, v_fog, v_lightmapUV, v_texcoord0, v_worldPos, v_envPack0, v_envPack1, v_envPack2, v_envPack3

#include <bgfx_shader.sh>
#if !(defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY_ALPHA_TEST))
#define NO_LEGACY_SHADING
#define NO_STARFIELD
#include <libraries/shading.glsl>
#endif

uniform vec4 TimeOfDay;
uniform vec4 ViewPositionAndTime;
uniform vec4 CameraPosition;

SAMPLER2D_AUTOREG(s_MatTexture);
SAMPLER2D_AUTOREG(s_LightMapTexture);
#if defined(SEASONS)
SAMPLER2D_AUTOREG(s_SeasonsTexture);
#endif

void main() {
#if defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY_ALPHA_TEST)
    #if defined(ALPHA_TEST) || defined(DEPTH_ONLY_ALPHA_TEST)
    vec4 diffuse = texture2D(s_MatTexture, v_texcoord0);
    if (diffuse.a < 0.5) {
        discard;
    }
    #endif
    gl_FragColor = vec4_splat(0.0);
    return;
#else

    vec4 diffuse = texture2D(s_MatTexture, v_texcoord0);
    float dimension = floor(v_worldPosition.w * 0.1 + 0.05);
    float matType = v_worldPosition.w - dimension * 10.0;
    vec3 normal = calculateFaceNormal(v_clipPosition.xyz, vec3_splat(0.0), matType);

#if defined(ALPHA_TEST)
    if (diffuse.a < 0.5) {
        discard;
    }
#endif

    float rainFactor = v_ditheringAndMaskTinting.x;
    vec3 camPos = CameraPosition.xyz;
    float time = ViewPositionAndTime.w;
    if (time < 0.001) {
        time = TimeOfDay.x * 1200.0;
    }
    vec3 ao = vec3_splat(1.0);

#if defined(SEASONS)
    vec4 seasonCol = texture2D(s_SeasonsTexture, v_color0.xy);
    diffuse.rgb *= mix(vec3_splat(1.0), vertexColor(seasonCol), v_color0.b);
    diffuse.a = 1.0;
    vec3 aoInput = vec3_splat(v_color0.a < 0.01 ? 1.0 : v_color0.a);
    ao = getGridAO(normal, aoInput, 1.0);
#else
    vec3 cleanCol = matType > 2.5 ? v_color0.rgb : vertexColor(v_color0);
    if (v_ditheringAndMaskTinting.y > 0.5) {
        float tintAlpha = v_color0.a < 0.01 ? 1.0 : v_color0.a;
        diffuse.rgb = mix(diffuse.rgb, diffuse.rgb * cleanCol, diffuse.a) * tintAlpha;
        diffuse.a = 1.0;
    } else {
        diffuse.rgb *= cleanCol;
        #if !defined(TRANSPARENT)
            diffuse.a = 1.0;
        #else
            diffuse.a *= v_color0.a;
        #endif
    }
    if (matType < 2.5) {
#if defined(ALPHA_TEST)
        float grid = 1.0;
#else
        float grid = matType < 0.5 ? 1.0 - distance(fract(v_worldPosition.xyz), vec3_splat(0.5)) : 1.0;
#endif
        ao = getGridAO(normal, v_color0.rgb, grid);
    }
#endif

    float roughness = 0.9;
#if defined(TRANSPARENT)
    if (diffuse.a < 0.95) {
        roughness = 0.05;
    }
    if (matType > 2.5) {
        if (v_fog.a < -0.5) {
            diffuse.a = 1.0;
        } else {
            vec3 dv = camPos - v_worldPos.xyz;
            float cosI = clamp(abs(dv.y) * inversesqrt(max(dot(dv, dv), 1e-8)), 0.0, 1.0);
            float F = fresnelWater(cosI);
            diffuse.a = mix(0.78, 0.98, F);
        }
    }
#endif
    diffuse.rgb = evaluateRenderChunkShadingPre(
        diffuse.rgb,
        v_worldPos.xyz,
        camPos,
        v_lightmapUV.xy,
        time,
        TimeOfDay.x,
        v_fog.rgb,
        v_fog.a,
        roughness,
        0.0,
        matType,
        dimension,
        rainFactor,
        ao,
        normal,
        v_lightmapUV.z,
        v_lightmapUV.w,
        v_ditheringAndMaskTinting.z,
        v_ditheringAndMaskTinting.w,
        v_worldPos.w,
        v_clipPosition.w,
        v_envPack0,
        v_envPack1,
        v_envPack2,
        v_envPack3
    );

    gl_FragColor = diffuse;
#endif
}
