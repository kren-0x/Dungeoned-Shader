$input v_clipPosition, v_color0, v_fog, v_layerUv, v_light, v_texcoord0, v_worldPos, v_entExtra, v_envPack0, v_envPack1, v_envPack2, v_envPack3

#include <bgfx_shader.sh>
#include <MinecraftRenderer.Materials/ActorUtil.dragonh>
#include <MinecraftRenderer.Materials/FogUtil.dragonh>
#include <MinecraftRenderer.Materials/GlintUtil.dragonh>
#include <MinecraftRenderer.Materials/DitherUtil.dragonh>
#include <MinecraftRenderer.Materials/PatternUtil.dragonh>
#if !(defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY_ALPHA_TEST))
#define ENTITY_SHADER_ONLY
#define NO_LEGACY_SHADING
#include <libraries/shading.glsl>
#endif

uniform vec4 ActorFPEpsilon;
uniform vec4 HudOpacity;
uniform vec4 GlintColor;
uniform vec4 TileLightColor;
uniform vec4 DitherParams;
uniform vec4 DitherParams2[3];
uniform vec4 DitheringEnabledToggle;
uniform vec4 PatternColors[7];
uniform vec4 PatternCount;
uniform vec4 PatternUVOffsetsAndScales[7];
uniform vec4 FogColor;
uniform vec4 TimeOfDay;
uniform vec4 CameraPosition;

SAMPLER2D_AUTOREG(s_MatTexture);
SAMPLER2D_AUTOREG(s_MatTexture1);
SAMPLER2D_AUTOREG(s_MatTexture2);

void main() {
#if defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY_ALPHA_TEST)
    gl_FragColor = vec4_splat(0.0);
    return;
#else

    vec4 albedo = texture2D(s_MatTexture, v_texcoord0);

#if defined(TINTING)
    albedo = applyActorPatterns(albedo, v_texcoord0, s_MatTexture2, PatternCount.x, PatternColors, PatternUVOffsetsAndScales);
#endif

    bool ditherDiscard = false;

#if defined(ALPHA_TEST)
    if (ditherDiscard || albedo.a < ActorFPEpsilon.x) {
        discard;
    }
#elif defined(TRANSPARENT) || defined(OPAQUE)
    if (ditherDiscard) {
        albedo.a = 0.0;
    }
#endif

    vec4 glintTex1 = texture2D(s_MatTexture1, fract(v_layerUv.xy)).rgbr * GlintColor;
    vec4 glintTex2 = texture2D(s_MatTexture1, fract(v_layerUv.zw)).rgbr * GlintColor;
    vec4 glintSrc = (glintTex1 + glintTex2) * TileLightColor;
    vec3 glintAP1 = toAP1(glintSrc.rgb * glintSrc.rgb);

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

    albedo.rgb = shadedCol;
    albedo.a *= HudOpacity.x;
    gl_FragColor = albedo;
#endif
}
