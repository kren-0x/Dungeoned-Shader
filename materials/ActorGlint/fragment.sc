$input v_clipPosition, v_color0, v_fog, v_layerUv, v_light, v_texcoord0, v_worldPos, v_entExtra, v_envPack0, v_envPack1, v_envPack2, v_envPack3

#include <bgfx_shader.sh>
#include <MinecraftRenderer.Materials/ActorUtil.dragonh>
#include <MinecraftRenderer.Materials/FogUtil.dragonh>
#include <MinecraftRenderer.Materials/GlintUtil.dragonh>
#include <MinecraftRenderer.Materials/DitherUtil.dragonh>
#if !(defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE))
#define ENTITY_SHADER_ONLY
#define NO_LEGACY_SHADING
#include <libraries/shading.glsl>
#endif

uniform vec4 ColorBased;
uniform vec4 ChangeColor;
uniform vec4 UseAlphaRewrite;
uniform vec4 TintedAlphaTestEnabled;
uniform vec4 MatColor;
uniform vec4 OverlayColor;
uniform vec4 TileLightColor;
uniform vec4 MultiplicativeTintColor;
uniform vec4 ActorFPEpsilon;
uniform vec4 HudOpacity;
uniform vec4 GlintColor;
uniform vec4 DitherParams;
uniform vec4 DitherParams2[3];
uniform vec4 DitheringEnabledToggle;
uniform vec4 FogColor;
uniform vec4 TimeOfDay;
uniform vec4 CameraPosition;

SAMPLER2D_AUTOREG(s_MatTexture);
SAMPLER2D_AUTOREG(s_MatTexture1);

void main() {
#if defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE)
    gl_FragColor = vec4_splat(0.0);
    return;
#else

    vec4 albedo = getActorAlbedoNoColorChange(v_texcoord0, s_MatTexture, s_MatTexture1, MatColor);
    float rawAlpha = albedo.a;

    bool ditherDiscard = false;

#if defined(ALPHA_TEST)
    float alpha = mix(albedo.a, albedo.a * OverlayColor.a, TintedAlphaTestEnabled.x);
    if (ditherDiscard || shouldDiscard(albedo.rgb, alpha, ActorFPEpsilon.x)) {
        discard;
    }
#endif

#if defined(CHANGE_COLOR_MULTI)
    albedo = applyMultiColorChange(albedo, ChangeColor.rgb, MultiplicativeTintColor.rgb);
#elif defined(CHANGE_COLOR)
    albedo = applyColorChange(albedo, ChangeColor, albedo.a);
    albedo.a *= ChangeColor.a;
#endif

#if defined(ALPHA_TEST)
    albedo.a = max(UseAlphaRewrite.x, albedo.a);
#endif

    albedo.rgb *= mix(vec3_splat(1.0), v_color0.rgb, ColorBased.x);
    albedo = applyOverlayColor(albedo, OverlayColor);

    vec4 glintTex1 = texture2D(s_MatTexture1, fract(v_layerUv.xy)).rgbr * GlintColor;
    vec4 glintTex2 = texture2D(s_MatTexture1, fract(v_layerUv.zw)).rgbr * GlintColor;
    vec4 glintSrc = (glintTex1 + glintTex2) * TileLightColor;
    vec3 glintAP1 = toAP1(glintSrc.rgb * glintSrc.rgb);

#if defined(EMISSIVE_ONLY)
    float emissiveFog = v_fog.a < -0.5 ? (-v_fog.a - 1.0) : v_fog.a;
    vec3 emissiveAP1 = applyFog(fastFromSRGB(albedo.rgb) + glintAP1, fastFromSRGB(v_fog.rgb), emissiveFog);
    albedo.rgb = applyTonemapPre(emissiveAP1, v_entExtra.x, v_entExtra.y, 1.0);
#else
    vec3 camPos = CameraPosition.xyz;
    float rainFactor = v_light.w;
    vec2 lightmapUV = v_light.xy;
    float dimension = v_light.z;
    float nLen2 = dot(v_clipPosition.xyz, v_clipPosition.xyz);
    vec3 normal = nLen2 > 1e-8 ? v_clipPosition.xyz * inversesqrt(nLen2) : vec3(0.0, 1.0, 0.0);
    vec3 shadedCol = evaluateEntityShadingPre(
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
        true,
        glintAP1
    );
#if defined(EMISSIVE)
    float emissiveFog = v_fog.a < -0.5 ? (-v_fog.a - 1.0) : v_fog.a;
    vec3 emissiveAP1 = applyFog(fastFromSRGB(albedo.rgb) + glintAP1, fastFromSRGB(v_fog.rgb), emissiveFog);
    vec3 emissiveCol = applyTonemapPre(emissiveAP1, v_entExtra.x, v_entExtra.y, 1.0);
    float emissiveFactor = clamp(1.0 - rawAlpha, 0.0, 1.0);
    albedo.rgb = mix(shadedCol, emissiveCol, emissiveFactor);
#else
    albedo.rgb = shadedCol;
#endif
#endif

#if defined(TRANSPARENT)
    albedo = applyHudOpacity(albedo, HudOpacity.x);
    if (ditherDiscard) {
        albedo.a = 0.0;
    }
#endif

    gl_FragColor = albedo;
#endif
}
