$input a_position, a_color0, a_texcoord0, a_indices, a_normal
#ifdef INSTANCING
    $input i_data1, i_data2, i_data3
#endif

$output v_clipPosition, v_color0, v_fog, v_light, v_texcoord0, v_worldPos, v_entExtra, v_envPack0, v_envPack1, v_envPack2, v_envPack3

#include <bgfx_shader.sh>
#include <MinecraftRenderer.Materials/DynamicUtil.dragonh>
#include <MinecraftRenderer.Materials/FogUtil.dragonh>
#include <MinecraftRenderer.Materials/TAAUtil.dragonh>
#include <libraries/env_pack.glsl>

uniform vec4 OverlayColor;
uniform vec4 TileLightColor;
uniform vec4 TileLightIntensity;
uniform vec4 FogColor;
uniform vec4 FogControl;
uniform vec4 UVAnimation;
uniform vec4 TimeOfDay;
uniform vec4 CameraPosition;
uniform mat4 Bones[8];

void main() {
    mat4 World = u_model[0];
    World = mul(World, Bones[int(a_indices)]);

    vec3 worldPosition;
    vec3 worldNormal;
#ifdef INSTANCING
    mat4 model = mtxFromCols(i_data1, i_data2, i_data3, vec4(0.0, 0.0, 0.0, 1.0));
    worldPosition = instMul(model, vec4(a_position, 1.0)).xyz;
    worldNormal = instMul(model, vec4(a_normal.xyz, 0.0)).xyz;
#else
    worldPosition = mul(World, vec4(a_position, 1.0)).xyz;
    worldNormal = mul(World, vec4(a_normal.xyz, 0.0)).xyz;
#endif
    worldNormal.y *= TileLightColor.a;

    vec4 position = jitterVertexPosition(worldPosition);

#if defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE)
    v_texcoord0 = vec2_splat(0.0);
    v_color0 = vec4_splat(0.0);
    v_clipPosition = vec4_splat(0.0);
    v_fog = vec4_splat(0.0);
    v_light = vec4_splat(0.0);
    v_worldPos = vec3_splat(0.0);
    v_entExtra = vec4_splat(0.0);
    v_envPack0 = uvec4(0u, 0u, 0u, 0u);
    v_envPack1 = uvec4(0u, 0u, 0u, 0u);
    v_envPack2 = uvec4(0u, 0u, 0u, 0u);
    v_envPack3 = uvec4(0u, 0u, 0u, 0u);
    gl_Position = position;
#else
    vec2 texcoord0 = applyUvAnimation(a_texcoord0, UVAnimation);
    float expectedFogX = 0.029 + (0.09 * FogControl.y * FogControl.y);
    bool netherCtrl = (FogControl.x < 0.15 && abs(FogControl.x - expectedFogX) < 0.035);
    bool underLava = (FogControl.x == 0.0 && FogColor.b < 0.01 && FogColor.r > 0.15);
    bool isNether = (netherCtrl || underLava);
    bool isEnd = (abs(FogColor.r - FogColor.b) < 0.06 && (FogColor.r - FogColor.g > 0.15 || (FogColor.g < 0.02 && FogColor.r > 0.04)));
    float dimension = isNether ? 1.0 : (isEnd ? 2.0 : 0.0);

    float rainFactor = dimension < 0.5 ? detectRain(FogControl.xyz) : 0.0;

    float cameraDepth = position.z;
    float fogIntensity = calculateFogIntensity(cameraDepth, FogControl.z, FogControl.x, FogControl.y);
    bool isUnderwater = (FogControl.x == 0.0 && FogControl.y < 0.85 && (FogColor.b > FogColor.r || FogColor.g > FogColor.r)) && !isNether && !isEnd;
    vec4 fog = vec4(FogColor.rgb, isUnderwater ? (-1.0 - fogIntensity) : fogIntensity);

    uvec4 p0;
    uvec4 p1;
    uvec4 p2;
    uvec4 p3;
    float exposure;
    float scotopicBase;
    float groundFogDensity;
    float sunFresnel;
    float twVis;
    packEnvVaryings(
        TimeOfDay.x, rainFactor,
        p0, p1, p2, p3,
        exposure, scotopicBase, groundFogDensity, sunFresnel, twVis
    );
    if (dimension > 0.5) {
        exposure = 1.0;
        scotopicBase = 0.0;
    }

    vec2 lightmapUV = resolveEntityLightmap(TileLightIntensity, TileLightColor, p0, rainFactor);
    vec4 light = vec4(lightmapUV, dimension, rainFactor);

    v_texcoord0 = texcoord0;
    v_color0 = a_color0;
    v_clipPosition = vec4(worldNormal, twVis);
    v_fog = fog;
    v_light = light;
    v_worldPos = worldPosition + CameraPosition.xyz;
    v_entExtra = vec4(exposure, scotopicBase, groundFogDensity, sunFresnel);
    v_envPack0 = p0;
    v_envPack1 = p1;
    v_envPack2 = p2;
    v_envPack3 = p3;
    gl_Position = position;
#endif
}
