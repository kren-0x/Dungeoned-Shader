$input v_clipPosition, v_color0, v_fog, v_light, v_texcoord0, v_texcoords, v_worldPos, v_entExtra, v_envPack0, v_envPack1, v_envPack2, v_envPack3

#include <bgfx_shader.sh>
#include <MinecraftRenderer.Materials/ActorUtil.dragonh>
#include <MinecraftRenderer.Materials/FogUtil.dragonh>
#include <MinecraftRenderer.Materials/DitherUtil.dragonh>
#include <MinecraftRenderer.Materials/BannerUtil.dragonh>
#if !(defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY_ALPHA_TEST))
#define ENTITY_SHADER_ONLY
#define NO_LEGACY_SHADING
#include <libraries/shading.glsl>
#endif

uniform vec4 ActorFPEpsilon;
uniform vec4 HudOpacity;
uniform vec4 DitherParams;
uniform vec4 DitherParams2[3];
uniform vec4 DitheringEnabledToggle;
uniform vec4 FogColor;
uniform vec4 TimeOfDay;
uniform vec4 CameraPosition;

SAMPLER2D_AUTOREG(s_MatTexture);

void main() {
#if defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY_ALPHA_TEST)
    gl_FragColor = vec4_splat(0.0);
    return;
#else

    vec4 baseTex = texture2D(s_MatTexture, v_texcoords.zw);
#if defined(TINTING)
    vec4 patternTex = texture2D(s_MatTexture, v_texcoords.xy);
    vec4 diffuse = applyBannerTint(baseTex, patternTex, v_color0);
#else
    vec4 diffuse = baseTex;
#endif

    bool ditherDiscard = false;

#if defined(ALPHA_TEST)
    if (ditherDiscard || diffuse.a < ActorFPEpsilon.x) {
        discard;
    }
#elif defined(TRANSPARENT) || defined(OPAQUE)
    if (ditherDiscard) {
        diffuse.a = 0.0;
    }
#endif

    vec3 camPos = CameraPosition.xyz;
    float rainFactor = v_light.w;
    vec2 lightmapUV = v_light.xy;
    float dimension = v_light.z;
    float nLen2 = dot(v_clipPosition.xyz, v_clipPosition.xyz);
    vec3 normal = nLen2 > 1e-8 ? v_clipPosition.xyz * inversesqrt(nLen2) : vec3(0.0, 1.0, 0.0);
    vec3 shadedCol = evaluateEntityShadingPre(
        diffuse.rgb,
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

    diffuse.rgb = shadedCol;
    diffuse.a *= HudOpacity.x;
    gl_FragColor = diffuse;
#endif
}
