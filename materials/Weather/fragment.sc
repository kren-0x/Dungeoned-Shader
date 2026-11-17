$input v_color0, v_fog, v_occlusionHeight, v_occlusionUV, v_texcoord0, v_worldPos

#include <bgfx_shader.sh>
#include <MinecraftRenderer.Materials/FogUtil.dragonh>
#include <libraries/color_spaces.glsl>

uniform vec4 OcclusionHeightOffset;

SAMPLER2D_AUTOREG(s_WeatherTexture);
SAMPLER2D_AUTOREG(s_OcclusionTexture);
SAMPLER2D_AUTOREG(s_LightingTexture);

float getOcclusionHeight(const vec4 occlSample) {
    float legacyHeight = occlSample.g + (occlSample.b * 255.0);
    float packedHeight = ((0.25 * occlSample.x) + fract(64.0 * occlSample.y)) * (1024.0 / 255.0);
    float baseHeight = max(legacyHeight, packedHeight);
    return baseHeight + (abs(OcclusionHeightOffset.x) + 0.75) * (1.0 / 255.0);
}

float getOcclusionLuminance(const vec4 occlSample) {
    return max(occlSample.r, fract(occlSample.z * 16.0));
}

bool isOccluded(const float occlHeight, const float occlHeightThreshold, const float occlLum) {
#if defined(NO_OCCLUSION)
    return false;
#else
    #if defined(FLIP_OCCLUSION)
        bool underRoof = occlHeight > occlHeightThreshold;
    #else
        bool underRoof = occlHeight <= occlHeightThreshold;
    #endif
    return underRoof || (occlLum < 0.08);
#endif
}

void main() {
    vec4 diffuse = texture2D(s_WeatherTexture, v_texcoord0);
    vec2 occlUV = fract(v_occlusionUV);
    vec4 occlSample = texture2D(s_OcclusionTexture, occlUV);

    float occlLum = getOcclusionLuminance(occlSample);
    float occlHeightThreshold = getOcclusionHeight(occlSample);

    if (isOccluded(v_occlusionHeight, occlHeightThreshold, occlLum)) {
        diffuse.a = 0.0;
    } else {
        float mixAmount = clamp((v_occlusionHeight - occlHeightThreshold) * 25.0, 0.0, 1.0);
        float uvX = occlLum * (1.0 - mixAmount);
        vec2 lightingUV = vec2(clamp(uvX, 0.0, 1.0), 1.0);
        vec3 light = texture2D(s_LightingTexture, lightingUV).rgb;

        float spriteLuma = dot(diffuse.rgb, vec3(0.2126, 0.7152, 0.0722));
        vec3 realisticWaterColor = mix(vec3_splat(spriteLuma), vec3(0.72, 0.78, 0.84) * spriteLuma, 0.15);

        vec3 lightAP1 = fromSRGB(light);
        vec3 fogAP1 = fromSRGB(v_fog.rgb);

        vec3 rainColAP1 = realisticWaterColor * lightAP1;
        rainColAP1 += fogAP1 * (0.20 * spriteLuma);
        rainColAP1 = applyFog(rainColAP1, fogAP1, v_fog.a);

        diffuse.rgb = ACEScgToDisplaySRGB(rainColAP1);

        float indoorFade = smoothstep(0.08, 0.28, occlLum);
        float fogFade = 1.0 - clamp(v_fog.a * 0.80, 0.0, 1.0);
        diffuse.a = clamp(diffuse.a * 0.70 * indoorFade * fogFade, 0.0, 1.0);
    }

    gl_FragColor = diffuse;
}
