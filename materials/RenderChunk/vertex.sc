$input a_color0, a_position, a_texcoord0, a_texcoord1
#ifdef INSTANCING
    $input i_data1, i_data2, i_data3
#endif

$output v_clipPosition, v_color0, v_ditheringAndMaskTinting, v_fog, v_lightmapUV, v_texcoord0, v_worldPos, v_worldPosition, v_envPack0, v_envPack1, v_envPack2, v_envPack3

#include <bgfx_shader.sh>
#include <MinecraftRenderer.Materials/TAAUtil.dragonh>
#include <libraries/env_pack.glsl>

uniform vec4 RenderChunkFogAlpha;
uniform vec4 FogAndDistanceControl;
uniform vec4 ViewPositionAndTime;
uniform vec4 FogColor;
uniform vec4 MeshContext;
uniform vec4 CameraPosition;
uniform vec4 TimeOfDay;

void main() {
#ifdef INSTANCING
    mat4 model = mtxFromCols(i_data1, i_data2, i_data3, vec4(0.0, 0.0, 0.0, 1.0));
    vec3 worldPos = instMul(model, vec4(a_position, 1.0)).xyz;
#else
    vec3 worldPos = mul(u_model[0], vec4(a_position, 1.0)).xyz;
#endif

    vec3 cPos = a_position.xyz;
    vec3 bPos = fract(cPos);
    vec3 cornerDist = min(bPos, 1.0 - bPos);
    bool isCubeCorner = max(cornerDist.x, max(cornerDist.y, cornerDist.z)) < 0.005;
    bool isColored = a_color0.r != a_color0.g || a_color0.r != a_color0.b;

#if (defined(ALPHA_TEST) || defined(DEPTH_ONLY_ALPHA_TEST)) && !defined(RENDER_AS_BILLBOARDS)
    bool isTree = isCubeCorner && (isColored || a_color0.a == 0.0);
    bool isPlants = isColored && (a_color0.r / max(a_color0.g, 0.001) < 1.9);
    bool isFoliage = isTree || isPlants;
#else
    bool isFoliage = false;
    bool isTree = false;
#endif

#ifdef SEASONS
    isFoliage = true;
    isTree = true;
#endif

#if defined(TRANSPARENT) && !(defined(RENDER_AS_BILLBOARDS) || defined(SEASONS))
    bool isWater = (a_color0.b > 0.3 || a_color0.g > 0.3) && a_color0.a < 0.95;
#else
    bool isWater = false;
#endif

    float matType = 0.0;
    if (isWater) {
        matType = 3.0;
    } else if (isTree) {
        matType = 1.0;
    } else if (isFoliage) {
        matType = 2.0;
    }

    if (matType > 0.5 && matType < 2.5) {
        float time = ViewPositionAndTime.w;
        float phase = dot(cPos, vec3_splat(0.785398)) + fract(cPos.x * 0.125 + cPos.z * 0.125);
        float wave = 0.035 * (sin(time * 2.8 + phase) + 0.3 * sin(time * 5.6 + phase));
        if (matType < 1.5) {
            wave *= 0.5;
        }
        worldPos.xz += vec2_splat(wave);
    }

#ifdef RENDER_AS_BILLBOARDS
    worldPos += vec3_splat(0.5);
    vec3 viewDir = normalize(worldPos - ViewPositionAndTime.xyz);
    vec3 boardPlane = normalize(cross(vec3(0.0, 1.0, 0.0), viewDir));
    worldPos -= (cross(viewDir, boardPlane) * (a_color0.z - 0.5)) + (boardPlane * (a_color0.x - 0.5));
    vec4 color = vec4_splat(1.0);
#else
    vec4 color = a_color0;
#endif

    vec4 position = jitterVertexPosition(worldPos);

#if defined(DEPTH_ONLY) || defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY_ALPHA_TEST)
    vec2 uv0 = vec2_splat(0.0);
    #if defined(ALPHA_TEST) || defined(DEPTH_ONLY_ALPHA_TEST)
    uvec2 uv0_16 = uvec2(round(a_texcoord0 * 65535.0));
    uv0 = vec2(float((uv0_16.x & 32767u) << uint(1)), float((uv0_16.y & 32767u) << uint(1))) * 1.525902189314365386962890625e-05;
    uv0.x += 3.0517578125e-05 * ((2.0 * float((uv0_16.x & 32768u) >> uint(15))) - 1.0);
    uv0.y += 3.0517578125e-05 * ((2.0 * float((uv0_16.y & 32768u) >> uint(15))) - 1.0);
    #endif
    v_clipPosition = vec4_splat(0.0);
    v_worldPosition = vec4_splat(0.0);
    v_color0 = vec4_splat(0.0);
    v_ditheringAndMaskTinting = vec4_splat(0.0);
    v_fog = vec4_splat(0.0);
    v_lightmapUV = vec4_splat(0.0);
    v_texcoord0 = uv0;
    v_worldPos = vec4_splat(0.0);
    v_envPack0 = uvec4(0u, 0u, 0u, 0u);
    v_envPack1 = uvec4(0u, 0u, 0u, 0u);
    v_envPack2 = uvec4(0u, 0u, 0u, 0u);
    v_envPack3 = uvec4(0u, 0u, 0u, 0u);
    gl_Position = position;
#else

    vec4 fogAndDist = FogAndDistanceControl;
    if (MeshContext.x > 0.5) {
        fogAndDist = vec4(0.99, 1.0, 100000.0, 100000.0);
    }

    uvec2 uv0_16 = uvec2(round(a_texcoord0 * 65535.0));
    vec2 uv0 = vec2(float((uv0_16.x & 32767u) << uint(1)), float((uv0_16.y & 32767u) << uint(1))) * 1.525902189314365386962890625e-05;
    uv0.x += 3.0517578125e-05 * ((2.0 * float((uv0_16.x & 32768u) >> uint(15))) - 1.0);
    uv0.y += 3.0517578125e-05 * ((2.0 * float((uv0_16.y & 32768u) >> uint(15))) - 1.0);

    uvec2 uv1_16 = uvec2(round(a_texcoord1 * 65535.0));
    float lightmapX = float((uv1_16.y >> 4u) & 15u) * 0.06666667;
    float lightmapY = float(uv1_16.y & 15u) * 0.06666667;
    vec2 lightmapUV = vec2(lightmapX, lightmapY);

    float ditherY = float((uv1_16.y & 256u) != 0u ? 1.0 : 0.0);

    float camDist = length(ViewPositionAndTime.xyz - worldPos);
    float fogIntensity = clamp((((camDist / fogAndDist.z) + RenderChunkFogAlpha.x) - fogAndDist.x) / (fogAndDist.y - fogAndDist.x), 0.0, 1.0);
    float expectedFogX = 0.029 + (0.09 * fogAndDist.y * fogAndDist.y);
    bool netherCtrl = (fogAndDist.x < 0.15 && abs(fogAndDist.x - expectedFogX) < 0.035);
    bool underLava = (fogAndDist.x == 0.0 && FogColor.b < 0.01 && FogColor.r > 0.15);
    bool isNether = (netherCtrl || underLava);
    bool isEnd = (abs(FogColor.r - FogColor.b) < 0.06 && (FogColor.r - FogColor.g > 0.15 || (FogColor.g < 0.02 && FogColor.r > 0.04)));
    float dimension = isNether ? 1.0 : (isEnd ? 2.0 : 0.0);
    bool isUnderwater = (fogAndDist.x == 0.0 && fogAndDist.y < 0.85 && (FogColor.b > FogColor.r || FogColor.g > FogColor.r)) && !isNether && !isEnd;

    float rainFactor = 0.0;
    if (dimension < 0.5 && !isUnderwater) {
        rainFactor = detectRain(FogAndDistanceControl.xyz);
    }

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

    vec3 fogAP1 = fromSRGB(FogColor.rgb);
    vec4 fog = vec4(fogAP1, isUnderwater ? (-1.0 - fogIntensity) : fogIntensity);
    float ca = clamp(0.082 * (CameraPosition.y - 63.0), -0.15, 20.0);

#if defined(TRANSPARENT)
    if (a_color0.a < 0.95) {
        color.a = mix(a_color0.a, 1.0, clamp(camDist / FogAndDistanceControl.w, 0.0, 1.0));
    }
#endif

    vec3 relPos = worldPos - ViewPositionAndTime.xyz;
    v_clipPosition = vec4(relPos, twVis);
    v_worldPosition = vec4(a_position, dimension * 10.0 + matType);
    v_color0 = color;
    v_ditheringAndMaskTinting = vec4(rainFactor, ditherY, groundFogDensity, ca);
    v_fog = fog;
    v_lightmapUV = vec4(lightmapUV, exposure, scotopicBase);
    v_texcoord0 = uv0;
    v_worldPos = vec4(relPos + CameraPosition.xyz, sunFresnel);
    v_envPack0 = p0;
    v_envPack1 = p1;
    v_envPack2 = p2;
    v_envPack3 = p3;
    gl_Position = position;
#endif
}
