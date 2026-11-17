$input v_clipPosition, v_color0, v_fog, v_light, v_texcoord0, v_worldPos, v_entExtra, v_envPack0, v_envPack1, v_envPack2, v_envPack3

#include <bgfx_shader.sh>
#include <MinecraftRenderer.Materials/DynamicUtil.dragonh>
#include <MinecraftRenderer.Materials/FogUtil.dragonh>
#include <MinecraftRenderer.Materials/DitherUtil.dragonh>
#if !defined(DEPTH_ONLY)
#define ENTITY_SHADER_ONLY
#define NO_LEGACY_SHADING
#include <libraries/shading.glsl>
#endif

uniform vec4 ChangeColor;
uniform vec4 OverlayColor;
uniform vec4 ColorBased;
uniform vec4 MultiplicativeTintColor;
uniform vec4 DitherParams;
uniform vec4 DitherParams2[3];
uniform vec4 DitheringEnabledToggle;
uniform vec4 FogColor;
uniform vec4 TimeOfDay;
uniform vec4 CameraPosition;
uniform vec4 TileLightColor;

void main() {
#if defined(DEPTH_ONLY)
    gl_FragColor = vec4_splat(0.0);
    return;
#else
    vec4 albedo = v_color0;
    vec3 tinted = mix(vec3_splat(1.0), albedo.rgb, ColorBased.x);

#if defined(MULTI_COLOR_TINT)
    vec2 colorMask = tinted.rg;
    vec3 multiTint = mix(tinted.r * ChangeColor.rgb, tinted.g * MultiplicativeTintColor.rgb, ceil(colorMask.g));
    albedo.rgb = mix(multiTint, OverlayColor.rgb, OverlayColor.a);
#else
    vec4 baseTint = vec4(tinted, 1.0);
    vec3 singleTint = mix(baseTint, baseTint * ChangeColor, albedo.a).rgb;
    albedo.rgb = mix(singleTint, OverlayColor.rgb, OverlayColor.a);
#endif

    bool ditherDiscard = false;

#if defined(ALPHA_TEST)
    if (ditherDiscard || albedo.a < 0.5) {
        discard;
    }
#elif defined(TRANSPARENT)
    if (ditherDiscard) {
        albedo.a = 0.0;
    }
#endif

    vec3 camPos = CameraPosition.xyz;
    float rainFactor = v_light.w;
    vec2 lightmapUV = v_light.xy;
    bool isEnd = (abs(FogColor.r - FogColor.b) < 0.06 && (FogColor.r - FogColor.g > 0.15 || (FogColor.g < 0.02 && FogColor.r > 0.04)));
    bool isNether = (FogColor.r > 0.15 && FogColor.b < 0.08) || (FogColor.b > 0.10 && FogColor.g > 0.10 && FogColor.r < 0.15 && lightmapUV.y < 0.05);
    float dimension = isNether ? 1.0 : (isEnd ? 2.0 : 0.0);
    float nLen2 = dot(v_clipPosition.xyz, v_clipPosition.xyz);
    vec3 normal = nLen2 > 1e-8 ? v_clipPosition.xyz * inversesqrt(nLen2) : vec3(0.0, 1.0, 0.0);
    albedo.rgb = evaluateEntityShadingPre(
        albedo.rgb,
        v_worldPos,
        camPos,
        lightmapUV,
        TimeOfDay.x,
        FogColor.rgb,
        v_fog.a,
        rainFactor,
        normal,
        v_entExtra.x,
        v_entExtra.y,
        v_entExtra.z,
        v_entExtra.w,
        v_clipPosition.w,
        v_envPack0,
        v_envPack1,
        v_envPack2,
        v_envPack3,
        dimension,
        true,
        true
    );

    gl_FragColor = albedo;
#endif
}
