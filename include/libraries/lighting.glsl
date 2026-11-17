#ifndef LIBRARIES_LIGHTING_GLSL
#define LIBRARIES_LIGHTING_GLSL

#include <libraries/common.glsl>
#include <libraries/color_spaces.glsl>
#include <libraries/brdf.glsl>
#include <libraries/luts.glsl>
#include <libraries/env_pack.glsl>
#include <libraries/water.glsl>
#include <libraries/surface.glsl>
#include <libraries/atmosphere.glsl>

MP float evalTorchAtten(MP float lmx) {
#if BGFX_SHADER_TYPE_FRAGMENT
    return texture2DLod(s_DungeonedLUT, vec2(lmx, 0.125), 0.0).r * 1.565;
#else
    MP float d = 1.0 - lmx;
    MP float core = (lmx * lmx * lmx) / (1.0 + 10.0 * d * d) * 1.55;
    MP float ambient = 0.015 * (lmx * lmx);
    return core + ambient;
#endif
}

MP float evalTorchAtten(MP float lmx, HP vec3 worldPos, MP vec3 N) {
    return evalTorchAtten(lmx);
}

void unpackEnvVaryings(
    uvec4 p0,
    uvec4 p1,
    uvec4 p2,
    uvec4 p3,
    out MP vec3 sunDir,
    out MP vec3 activeDir,
    out MP vec3 activeCol,
    out MP vec3 ambTop,
    out MP vec3 ambBot,
    out MP vec3 horAnti,
    out MP vec3 horSun,
    out MP vec3 midAnti,
    out MP vec3 midSun,
    out MP vec3 skyZenith,
    out MP float dayFactor,
    out MP float goldenFactor,
    out MP float nightFactor
) {
    MP vec2 q0x = unpackHalf2x16(p0.x);
    MP vec2 q0y = unpackHalf2x16(p0.y);
    MP vec2 q0z = unpackHalf2x16(p0.z);
    MP vec2 q0w = unpackHalf2x16(p0.w);
    sunDir = vec3(q0x, q0y.x);
    activeDir = sunDir.y >= 0.0 ? sunDir : -sunDir;
    activeCol = vec3(q0y.y, q0z);
    dayFactor = q0w.x;
    goldenFactor = q0w.y;

    MP vec2 q1x = unpackHalf2x16(p1.x);
    MP vec2 q1y = unpackHalf2x16(p1.y);
    MP vec2 q1z = unpackHalf2x16(p1.z);
    MP vec2 q1w = unpackHalf2x16(p1.w);
    ambTop = vec3(q1x, q1y.x);
    ambBot = vec3(q1y.y, q1z);
    nightFactor = q1w.x;

    MP vec2 q2x = unpackHalf2x16(p2.x);
    MP vec2 q2y = unpackHalf2x16(p2.y);
    MP vec2 q2z = unpackHalf2x16(p2.z);
    MP vec2 q2w = unpackHalf2x16(p2.w);
    horAnti = vec3(q2x, q2y.x);
    horSun = vec3(q2y.y, q2z);

    MP vec2 q3x = unpackHalf2x16(p3.x);
    MP vec2 q3y = unpackHalf2x16(p3.y);
    MP vec2 q3z = unpackHalf2x16(p3.z);
    MP vec2 q3w = unpackHalf2x16(p3.w);
    midAnti = vec3(q3x, q3y.x);
    midSun = vec3(q3y.y, q3z);
    skyZenith = vec3(q2w, q3w.x);
}

MP vec3 applyTonemapPre(MP vec3 col, MP float exposure, MP float scotopicBase, MP float torchWeight, MP float skyFactor) {
    MP float scotopic = scotopicBase * clamp(1.0 - torchWeight * 2.0, 0.0, 1.0);
    HP vec3 lin = AP1ToLinearSRGB(col * exposure);
    if (scotopic > 0.001) {
        HP float luma = dot(lin, vec3(0.2126, 0.7152, 0.0722));
        HP vec3 rodCol = vec3(luma * 0.6, luma * 0.85, luma * 1.25);
        lin = mix(lin, rodCol, scotopic * 0.45);
        HP vec3 scotopicFloor = vec3(0.00048, 0.00048, 0.00065) * (scotopic * smoothstep(0.02, 0.20, skyFactor));
        lin = max(lin, scotopicFloor);
    }
#if BGFX_SHADER_TYPE_FRAGMENT
    HP vec3 u = lin / (lin + vec3_splat(0.5));
    return vec3(
        texture2DLod(s_DungeonedTonemap, vec2(u.r, 0.5), 0.0).r,
        texture2DLod(s_DungeonedTonemap, vec2(u.g, 0.5), 0.0).g,
        texture2DLod(s_DungeonedTonemap, vec2(u.b, 0.5), 0.0).b
    );
#else
    return tonemapLottes(lin);
#endif
}

MP vec3 applyTonemapPre(MP vec3 col, MP float exposure, MP float scotopicBase, MP float torchWeight) {
    return applyTonemapPre(col, exposure, scotopicBase, torchWeight, 1.0);
}

#ifndef ENTITY_SHADER_ONLY
vec3 evaluateRenderChunkShadingPre(
    vec3 albedoSRGB,
    vec3 worldPos,
    vec3 camPos,
    vec2 lightmapUV,
    float time,
    float timeOfDay,
    vec3 fogAP1,
    float fogFactor,
    float roughness,
    float metallic,
    float matType,
    float dimension,
    float rainFactor,
    vec3 ao,
    vec3 surfaceNormal,
    float exposure,
    float scotopicBase,
    float groundFogDensity,
    float ca,
    float sunFresnel,
    float twVis,
    uvec4 p0,
    uvec4 p1,
    uvec4 p2,
    uvec4 p3
) {
    MP float isUnderwater = 0.0;
    MP float actualFogFactor = fogFactor;
    if (fogFactor < -0.5) {
        isUnderwater = 1.0;
        actualFogFactor = -fogFactor - 1.0;
    }

    vec3 viewVec = camPos - worldPos;
    float hitDist2 = dot(viewVec, viewVec);
    float invHitDist = inversesqrt(max(hitDist2, 1e-8));
    float hitDist = hitDist2 * invHitDist;
    MP vec3 v = viewVec * invHitDist;
    MP vec3 rd = -v;

    MP vec3 sunDir;
    MP vec3 activeDir;
    MP vec3 activeCol;
    MP vec3 ambTop;
    MP vec3 ambBot;
    MP vec3 horAnti;
    MP vec3 horSun;
    MP vec3 midAnti;
    MP vec3 midSun;
    MP vec3 skyZenith;
    MP float dayFactor;
    MP float goldenFactor;
    MP float nightFactor;
    unpackEnvVaryings(
        p0, p1, p2, p3,
        sunDir, activeDir, activeCol, ambTop, ambBot,
        horAnti, horSun, midAnti, midSun, skyZenith,
        dayFactor, goldenFactor, nightFactor
    );

    float cloudTime = (dimension > 1.5) ? time : (timeOfDay * 1200.0);
    MP vec3 hFogAP1 = fogAP1;
    MP float hRain = rainFactor;

    MP vec3 albedo = fastFromSRGB(albedoSRGB);

    MP float skyFactor = clamp(lightmapUV.y, 0.0, 1.0);
    MP float skyShadowThreshold = mix(0.85, 0.65, hRain);
    MP float skyShadow = clamp((skyFactor - skyShadowThreshold) / max(1.0 - skyShadowThreshold, 0.01), 0.0, 1.0);
    skyShadow = skyShadow * skyShadow * (3.0 - 2.0 * skyShadow);

    MP float lmx = clamp(lightmapUV.x, 0.0, 1.0);
    MP float torchAtten = evalTorchAtten(lmx, worldPos, surfaceNormal);

    MP float shadowm = 0.0;
    if (dimension < 0.5) {
        MP float skySq = skyFactor * skyFactor;
        shadowm = 1.0 - smoothstep(0.860, 0.875, skySq);
        MP float tx = max(lightmapUV.x * 1.2, 0.0);
        MP float tx2 = tx * tx;
        MP float des = tx2 * tx2 * tx2;
        shadowm = max(0.0, shadowm - 0.7 * des);
    } else {
        skyShadow = 0.0;
        if (dimension < 1.5) {
            ambTop = hFogAP1 * 0.70 + NETHER_AMB_BASE_AP1;
            ambBot = hFogAP1 * 0.45 + NETHER_AMB_BOT_AP1;
        } else {
            ambTop = END_AMB_BASE_AP1;
            ambBot = END_AMB_BOT_AP1;
        }
    }

    MP float cloudShadow = 1.0;
    if (dimension < 0.5 && skyShadow > 0.001 && activeDir.y > 0.01) {
        cloudShadow = getCloudShadow(worldPos, activeDir, cloudTime, hRain);
    }

#if defined(TRANSPARENT)
    if (matType > 2.5) {
        bool isBelow = (camPos.y < worldPos.y) || (isUnderwater > 0.5);
        MP vec3 baseWater = isUnderwater > 0.5 ? hFogAP1 : mix(WATER_SCATTER_AP1, hFogAP1, 0.35);
        MP vec3 waterBase = mix(albedo, baseWater, 0.70);

        MP vec3 sunGlow = getSunGlowPre(sunDir.y, goldenFactor, hRain);
        MP vec3 moonGlow = getMoonGlowPre(nightFactor, hRain);
        MP vec3 cloudLit;
        MP vec3 cloudShade;
        MP vec3 cloudRim;
        getCloudColorsPre(sunDir.y, dayFactor, goldenFactor, hRain, twVis, cloudLit, cloudShade, cloudRim);

        MP vec3 waterCol;
        if (isBelow) {
            MP vec3 nBelow = waterSurfaceNormal(worldPos, vec3(0.0, -1.0, 0.0), hitDist, time);
            MP vec3 viewUp = -v;
            MP float upGrad = viewUp.y;
            MP float snellRadius = 0.58 + 0.08 * (nBelow.x + nBelow.z);
            MP float snellMask = smoothstep(snellRadius - 0.06, snellRadius + 0.06, upGrad);

            MP vec3 opaqueBlue = isUnderwater > 0.5
                ? waterFogInScatterPre(rd, activeDir, activeCol, hFogAP1, dayFactor, goldenFactor, sunFresnel, skyFactor) * (0.90 + 0.12 * (nBelow.x + nBelow.z))
                : WATER_SCATTER_AP1 * (ambTop * (0.75 * skyFactor * skyFactor) + CAVE_AMB_AP1 * (0.35 * (1.0 - skyFactor * skyFactor)) + 0.25 * skyFactor);

            MP vec3 refrDir = normalize(vec3(viewUp.x * 1.33, max(viewUp.y, 0.08), viewUp.z * 1.33));
            MP vec3 outsideSky = getSkyPre(
                worldPos, refrDir, sunDir, activeDir, horAnti, horSun, midAnti, midSun,
                skyZenith, sunGlow, moonGlow, cloudLit, cloudShade, cloudRim,
                cloudTime, goldenFactor, hRain, true
            );
            waterCol = mix(opaqueBlue, outsideSky, snellMask * smoothstep(0.10, 0.50, skyFactor));
        } else {
            MP vec3 n = waterSurfaceNormal(worldPos, vec3(0.0, 1.0, 0.0), hitDist, time);
            MP float cosI = clamp(dot(v, n), 0.0, 1.0);
            MP float F = fresnelWater(cosI);

            MP vec3 rr = reflect(rd, n);
            if (rr.y < 0.02) {
                rr = normalize(vec3(rr.x, max(rr.y, 0.02), rr.z));
            }
            MP vec3 refl = getSkyPre(
                worldPos, rr, sunDir, activeDir, horAnti, horSun, midAnti, midSun,
                skyZenith, sunGlow, moonGlow, cloudLit, cloudShade, cloudRim,
                cloudTime, goldenFactor, hRain, true
            );

            MP float waterSky = skyFactor * skyFactor;
            MP vec3 inside = waterBase * (ambTop * (0.75 * waterSky) + CAVE_AMB_AP1 * (0.45 * (1.0 - waterSky)) + activeCol * max(activeDir.y, 0.0) * (0.25 * skyShadow * cloudShadow));

            MP float waterGold = goldenFactor * (1.0 - hRain) * clamp(skyFactor * 1.4, 0.0, 1.0);
            if (waterGold > 0.001) {
                MP float reflHorizLen = length(rr.xz);
                MP float sunHz = length(sunDir.xz);
                MP vec2 sunDirNormXZ = sunHz > 1e-4 ? sunDir.xz / sunHz : vec2(1.0, 0.0);
                MP float reflSunAlign = reflHorizLen > 1e-4 ? clamp(dot(rr.xz / reflHorizLen, sunDirNormXZ) * 0.5 + 0.5, 0.0, 1.0) : 0.5;
                inside = mix(inside, GOLD_WATER_TINT_AP1 * 0.14, 0.45 * waterGold) + waterBase * sunGlow * (0.20 * waterGold);
                refl = mix(refl, GOLD_WATER_TINT_AP1 * max(luminanceAP1(refl) * 1.15, 0.28), (0.20 + 0.35 * reflSunAlign) * waterGold * (0.55 + 0.45 * F));
            }

            MP float skyReflFade = smoothstep(0.15, 0.60, skyFactor);
            MP vec3 caveCeilRefl = waterBase * (TORCH_COLOR_AP1 * (torchAtten * 0.55) + CAVE_AMB_AP1 * (0.35 * (1.0 - waterSky)) + ambTop * (0.10 * waterSky));
            MP vec3 effectiveRefl = mix(caveCeilRefl, refl, skyReflFade);
            MP float reflWeight = mix(0.85, 0.98, F) * mix(0.25 + 0.75 * min(torchAtten * 1.5, 1.0), 1.0, skyReflFade);

            MP vec3 glint = vec3_splat(0.0);
            MP float NoL = dot(n, activeDir);
            if (NoL > 0.0 && skyShadow > 0.001) {
                MP vec3 h = normalize(v + activeDir);
                MP float NoH = clamp(dot(n, h), 0.0, 1.0);
                MP float VoH = clamp(dot(v, h), 0.0, 1.0);
                MP float NoV = clamp(dot(n, v), 1e-4, 1.0);
                HP float D = D_GGX(NoH, 0.0036);
                MP float V = V_SmithGGXCorrelated(NoV, NoL, 0.0036);
                MP float Fspec = F_SchlickScalar(VoH, 0.02);
                MP vec3 spec = (D * V * Fspec * 1.00107) * activeCol * NoL;
                MP float sp = dot(spec, vec3_splat(0.3333));
                glint = (activeCol * (smoothstep(1.0, 3.5, sp) * 0.7) + spec * 0.05) * (skyShadow * cloudShadow);
            }

            waterCol = mix(inside, effectiveRefl, reflWeight) + glint;
        }

        MP vec3 waterTorchCol = (dimension < 0.5) ? TORCH_COLOR_OVERWORLD_AP1 : TORCH_COLOR_AP1;
        waterCol += waterBase * waterTorchCol * torchAtten;
        MP vec3 foggedCol = applyAtmospherePre(
            waterCol, camPos, rd, worldPos, hitDist,
            sunDir, activeDir, activeCol, ambTop, horAnti, horSun, midAnti, midSun, skyZenith,
            hFogAP1, dayFactor, goldenFactor, nightFactor, hRain, groundFogDensity, ca, sunFresnel, twVis,
            actualFogFactor, isUnderwater, skyFactor, cloudTime, dimension, true
        );
        return applyTonemapPre(foggedCol, exposure, scotopicBase, lightmapUV.x, skyFactor);
    }
#endif

    MP vec3 N = surfaceNormal;
    MP float NoL = dot(N, activeDir);
    MP vec3 directDiff = vec3_splat(0.0);
    MP vec3 directSpec = vec3_splat(0.0);
    MP float Fspec = 0.0;

#if defined(ALPHA_TEST) || defined(SEASONS)
    if (matType > 0.5 && matType < 2.5) {
        if (skyShadow > 0.001) {
            MP float wrap = matType < 1.5 ? 0.40 : 0.35;
            MP float diffSun = clamp((NoL + wrap) / (1.0 + wrap), 0.0, 1.0);
            if (matType < 1.5) {
                diffSun *= 1.15;
            }
            MP float b = clamp(dot(v, -activeDir), 0.0, 1.0);
            MP float b2 = b * b;
            MP float backLight = b2 * b2 * 0.45 + clamp(-NoL * 0.40, 0.0, 0.30);
            MP vec3 sssTint = albedo * FOLIAGE_SSS_TINT_AP1;
            MP float sssIntensity = matType < 1.5 ? 0.45 : 0.35;
            MP vec3 sssLight = sssTint * activeCol * backLight * sssIntensity * skyShadow;
            directDiff = albedo * activeCol * diffSun * skyShadow + sssLight;
        }
    } else
#endif
    {
        MP float wrap = mix(0.32, 0.16, goldenFactor);
        if (skyShadow > 0.001 && NoL > -wrap) {
#if defined(TRANSPARENT)
            MP float wrappedNoL = clamp((NoL + wrap) / (1.0 + wrap), 0.0, 1.0);
            MP float oren = 0.0;
            if (NoL > 0.0) {
                oren = Fd_OrenNayar(N, v, activeDir, roughness) * PI;
            }
            MP float diffSun = mix(oren, wrappedNoL, mix(0.50, 0.32, goldenFactor));
#else
            MP float diffSun = texture2DLod(s_DungeonedLUT, vec2(clamp((NoL + 0.5) * 0.666667, 0.0, 1.0), goldenFactor), 0.0).b;
#endif
            directDiff = albedo * activeCol * diffSun * skyShadow;

            if (NoL > 0.0) {
                MP vec3 h = normalize(v + activeDir);
                MP float NoH = clamp(dot(N, h), 0.0, 1.0);
                MP float VoH = clamp(dot(v, h), 0.0, 1.0);
                MP float NoV = clamp(dot(N, v), 1e-4, 1.0);
                MP float clampedNoL = clamp(NoL, 0.0, 1.0);
#if defined(TRANSPARENT)
                MP float a = max(roughness * roughness, 0.002);
                MP float energyComp = 1.0 + 0.04 * (1.0 / max(0.15 + 0.85 * (1.0 - roughness), 0.1) - 1.0);
#else
                MP float a = 0.81;
                MP float energyComp = 1.130213;
#endif
                HP float D = D_GGX(NoH, a);
                MP float V = V_SmithGGXCorrelated(NoV, clampedNoL, a);
                Fspec = F_SchlickScalar(VoH, 0.04);
                directSpec = (D * V * Fspec * energyComp) * activeCol * clampedNoL * skyShadow;
            }
        }
    }

    MP vec3 directSun = (directDiff * (1.0 - Fspec) + directSpec) * (1.14 * cloudShadow);

    MP float sunLit = clamp(NoL, 0.0, 1.0) * skyShadow * cloudShadow;
    MP float brightDamp = mix(1.0, 0.45, sunLit);

    MP float sideFactor = 1.0 - abs(N.y);
    MP vec3 skyAmb = mix(ambBot, ambTop, clamp(0.35 + 0.45 * N.y + 0.30 * sideFactor, 0.0, 1.0));
    MP vec3 sideSkylight = ambTop * 0.35 * sideFactor;
    MP vec3 bounceAmb;
    if (dimension > 0.5) {
        if (dimension < 1.5) {
            bounceAmb = vec3(0.050, 0.022, 0.010) * (0.30 + 0.70 * max(-N.y, 0.0));
        } else {
            bounceAmb = vec3_splat(0.0);
        }
    } else {
        bounceAmb = BOUNCE_AMB_TINT_AP1 * activeCol * 0.10 * (0.30 + 0.70 * sideFactor) * smoothstep(0.0, 0.35, activeDir.y);
    }
    MP float skyFade = dimension > 0.5 ? 1.0 : skyFactor * skyFactor;
    MP float ambFactor = (dimension > 0.5 && dimension < 1.5) ? 0.80 : (dimension > 1.5 ? 1.0 : 0.75 * skyFade);
    MP vec3 caveAmb = dimension > 0.5 ? vec3_splat(0.0) : CAVE_AMB_AP1 * ((0.65 + 0.35 * N.y) * mix(1.0, 1.45, dayFactor) * (1.0 - skyFade));
    MP vec3 totalAmb = ((skyAmb + sideSkylight + bounceAmb) * ambFactor + caveAmb) * brightDamp;
    MP vec3 ambientLight = albedo * totalAmb * ao;

    MP vec3 torchCol = (dimension < 0.5) ? TORCH_COLOR_OVERWORLD_AP1 : TORCH_COLOR_DIM_AP1;
    MP vec3 torchLight = albedo * torchCol * torchAtten * mix(vec3_splat(0.75), vec3_splat(1.0), ao);

    MP float minAmbWeight = 0.14 * skyFade * brightDamp;
    MP vec3 minAmb = albedo * (ambTop * minAmbWeight) * ao;
    MP float shadowFillAmt = mix(0.12, 0.05, goldenFactor);
    MP float shadowAmbAtten = mix(0.24, 0.44, goldenFactor);
    MP vec3 shadowSkyFill = albedo * ambTop * (shadowFillAmt * shadowm * skyFactor) * ao;
    directSun *= mix(vec3_splat(0.65), vec3_splat(1.0), ao) * (1.0 - 0.35 * shadowm);
    MP vec3 surfaceCol = (ambientLight + minAmb) * (1.0 - shadowAmbAtten * shadowm) + shadowSkyFill + directSun + torchLight;

    MP float outdoor = clamp(lightmapUV.y * 1.8 - 0.7, 0.0, 1.0);
    MP float wetFactor = hRain * outdoor;
    if (matType < 2.5 && wetFactor > 0.001 && N.y > 0.25 && hitDist < 80.0) {
        MP float puddleN = texture2DLod(s_DungeonedNoise, (worldPos.xz * 0.40 + vec2(3.1, 5.7)) * 0.03125, 0.0).r;
        MP float isPuddle = smoothstep(0.48, 0.62, puddleN) * wetFactor * smoothstep(0.55, 0.85, N.y);
        MP vec2 rainRipple = vec2_splat(0.0);
        if (hitDist < 50.0 && isPuddle > 0.001) {
            HP vec2 uv1 = worldPos.xz * 0.25 + vec2(time * 0.15, time * 0.08);
            HP vec2 uv2 = worldPos.xz * 0.38 - vec2(time * 0.11, time * 0.14);
            MP vec2 rip1 = texture2DLod(s_DungeonedNoise, uv1, 0.0).gb * 2.0 - vec2_splat(1.0);
            MP vec2 rip2 = texture2DLod(s_DungeonedNoise, uv2, 0.0).gb * 2.0 - vec2_splat(1.0);
            rainRipple = (rip1 + rip2) * 0.35;
        }
        rainRipple *= wetFactor;

        MP vec3 reflN = normalize(vec3(N.x - rainRipple.x, N.y, N.z - rainRipple.y));
        MP float cosTheta = clamp(dot(v, reflN), 0.0, 1.0);
        MP float fresnel = texture2DLod(s_DungeonedLUT, vec2(cosTheta, 0.875), 0.0).a;

        MP vec3 wetRefl = ambTop * mix(0.75, 1.15, reflN.y);
        MP vec3 pTorchCol = (dimension < 0.5) ? TORCH_COLOR_OVERWORLD_AP1 : TORCH_COLOR_DIM_AP1;
        MP float torchAttenWet = lmx * lmx * lmx * lmx;
        wetRefl += pTorchCol * (torchAttenWet * 0.65);

        MP float distFade = clamp(2.0 - 2.0 * hitDist * 0.015, 0.0, 1.0);
        MP float blockWet = wetFactor * smoothstep(0.25, 0.75, N.y);

        surfaceCol *= (1.0 - 0.28 * isPuddle);
        surfaceCol += wetRefl * (isPuddle * mix(0.15, 0.70, fresnel) * distFade);
        surfaceCol += wetRefl * (0.22 * blockWet * (0.04 + 0.96 * fresnel) * distFade);
    }

    MP vec3 foggedCol = applyAtmospherePre(
        surfaceCol, camPos, rd, worldPos, hitDist,
        sunDir, activeDir, activeCol, ambTop, horAnti, horSun, midAnti, midSun, skyZenith,
        hFogAP1, dayFactor, goldenFactor, nightFactor, hRain, groundFogDensity, ca, sunFresnel, twVis,
        actualFogFactor, isUnderwater, skyFactor, cloudTime, dimension, true
    );

    return applyTonemapPre(foggedCol, exposure, scotopicBase, lightmapUV.x, skyFactor);
}

#endif

vec3 evaluateEntityShadingPre(
    vec3 albedoSRGB,
    vec3 worldPos,
    vec3 camPos,
    vec2 lightmapUV,
    float timeOfDay,
    vec3 fogCol,
    float fogFactor,
    float rainFactor,
    vec3 surfaceNormal,
    float exposure,
    float scotopicBase,
    float groundFogDensity,
    float sunFresnel,
    float twVis,
    uvec4 p0,
    uvec4 p1,
    uvec4 p2,
    uvec4 p3,
    float dimension,
    bool allowCloudShadow,
    bool allowGroundFog,
    vec3 glintAP1
) {
    MP float isUnderwater = 0.0;
    MP float actualFogFactor = fogFactor;
    if (fogFactor < -0.5) {
        isUnderwater = 1.0;
        actualFogFactor = -fogFactor - 1.0;
    }

    vec3 viewVec = camPos - worldPos;
    float hitDist2 = dot(viewVec, viewVec);
    float invHitDist = inversesqrt(max(hitDist2, 1e-8));
    float hitDist = hitDist2 * invHitDist;
    MP vec3 v = viewVec * invHitDist;
    MP vec3 rd = -v;

    MP vec3 sunDir;
    MP vec3 activeDir;
    MP vec3 activeCol;
    MP vec3 ambTop;
    MP vec3 ambBot;
    MP vec3 horAnti;
    MP vec3 horSun;
    MP vec3 midAnti;
    MP vec3 midSun;
    MP vec3 skyZenith;
    MP float dayFactor;
    MP float goldenFactor;
    MP float nightFactor;
    unpackEnvVaryings(
        p0, p1, p2, p3,
        sunDir, activeDir, activeCol, ambTop, ambBot,
        horAnti, horSun, midAnti, midSun, skyZenith,
        dayFactor, goldenFactor, nightFactor
    );

    float cloudTime = timeOfDay * 1200.0;
    MP float hRain = rainFactor;

    MP vec3 albedo = fastFromSRGB(albedoSRGB);

    MP float skyFactor = clamp(lightmapUV.y, 0.0, 1.0);
    MP float skyShadowThreshold = mix(0.85, 0.65, hRain);
    MP float skyShadow = clamp((skyFactor - skyShadowThreshold) / max(1.0 - skyShadowThreshold, 0.01), 0.0, 1.0);
    skyShadow = skyShadow * skyShadow * (3.0 - 2.0 * skyShadow);

    MP float skySq = skyFactor * skyFactor;
    MP float shadowm = 1.0 - smoothstep(0.860, 0.875, skySq);
    MP float tx = max(lightmapUV.x * 1.2, 0.0);
    MP float tx2 = tx * tx;
    MP float des = tx2 * tx2 * tx2;
    shadowm = max(0.0, shadowm - 0.7 * des);

    MP vec3 hFogAP1 = fastFromSRGB(fogCol);
    if (dimension > 0.5) {
        skyShadow = 0.0;
        shadowm = 0.0;
        if (dimension < 1.5) {
            ambTop = hFogAP1 * 0.70 + NETHER_AMB_BASE_AP1;
            ambBot = hFogAP1 * 0.45 + NETHER_AMB_BOT_AP1;
        } else {
            ambTop = END_AMB_BASE_AP1;
            ambBot = END_AMB_BOT_AP1;
        }
    }

    MP float cloudShadow = 1.0;
    if (dimension < 0.5 && allowCloudShadow && skyShadow > 0.001 && activeDir.y > 0.01) {
        cloudShadow = getCloudShadow(worldPos, activeDir, cloudTime, hRain);
    }

    MP vec3 N = surfaceNormal;
    MP float NoL = dot(N, activeDir);
    MP vec3 directDiff = vec3_splat(0.0);
    MP vec3 directSpec = vec3_splat(0.0);
    MP float Fspec = 0.0;

    MP float wrap = mix(0.32, 0.16, goldenFactor);
    if (dimension < 0.5 && skyShadow > 0.001 && NoL > -wrap) {
        MP float diffSun = texture2DLod(s_DungeonedLUT, vec2(clamp((NoL + 0.5) * 0.666667, 0.0, 1.0), goldenFactor), 0.0).b;
        directDiff = albedo * activeCol * diffSun * skyShadow;

        if (NoL > 0.0) {
            MP vec3 h = normalize(v + activeDir);
            MP float NoH = clamp(dot(N, h), 0.0, 1.0);
            MP float VoH = clamp(dot(v, h), 0.0, 1.0);
            MP float NoV = clamp(dot(N, v), 1e-4, 1.0);
            MP float clampedNoL = clamp(NoL, 0.0, 1.0);
            HP float D = D_GGX(NoH, 0.7225);
            MP float V = V_SmithGGXCorrelated(NoV, clampedNoL, 0.7225);
            Fspec = F_SchlickScalar(VoH, 0.04);
            directSpec = (D * V * Fspec * 1.104110) * activeCol * clampedNoL * skyShadow;
        }
    }

    MP vec3 directSun = (dimension < 0.5) ? ((directDiff * (1.0 - Fspec) + directSpec) * (1.14 * cloudShadow)) : vec3_splat(0.0);
    MP float sunLit = (dimension < 0.5) ? (clamp(NoL, 0.0, 1.0) * skyShadow * cloudShadow) : 0.0;
    MP float brightDamp = mix(1.0, 0.45, sunLit);

    MP float sideFactor = 1.0 - abs(N.y);
    MP vec3 skyAmb = mix(ambBot, ambTop, clamp(0.35 + 0.45 * N.y + 0.30 * sideFactor, 0.0, 1.0));
    MP vec3 sideSkylight = ambTop * 0.35 * sideFactor;
    MP vec3 bounceAmb;
    if (dimension > 0.5) {
        if (dimension < 1.5) {
            bounceAmb = vec3(0.050, 0.022, 0.010) * (0.30 + 0.70 * max(-N.y, 0.0));
        } else {
            bounceAmb = vec3_splat(0.0);
        }
    } else {
        bounceAmb = BOUNCE_AMB_TINT_AP1 * activeCol * 0.10 * (0.30 + 0.70 * sideFactor) * smoothstep(0.0, 0.35, activeDir.y);
    }
    MP float skyFade = dimension > 0.5 ? 1.0 : skyFactor * skyFactor;
    MP float ambFactor = (dimension > 0.5 && dimension < 1.5) ? 0.80 : (dimension > 1.5 ? 1.0 : 0.75 * skyFade);
    MP vec3 caveAmb = dimension > 0.5 ? vec3_splat(0.0) : CAVE_AMB_AP1 * ((0.65 + 0.35 * N.y) * mix(1.0, 1.45, dayFactor) * (1.0 - skyFade));
    MP vec3 totalAmb = ((skyAmb + sideSkylight + bounceAmb) * ambFactor + caveAmb) * brightDamp;
    MP float entDir = max(N.y, 0.0) + abs(N.z) * 0.82 + abs(N.x) * 0.68 + max(-N.y, 0.0) * 0.50;
    MP float entAO = clamp(entDir, 0.48, 1.0);
    MP vec3 ambientLight = albedo * totalAmb * entAO;

    MP float lmx = clamp(lightmapUV.x, 0.0, 1.0);
    MP float torchAtten = evalTorchAtten(lmx, worldPos, N);
    MP vec3 torchCol = (dimension < 0.5) ? TORCH_COLOR_OVERWORLD_AP1 : TORCH_COLOR_DIM_AP1;
    MP vec3 torchLight = albedo * torchCol * torchAtten * mix(vec3_splat(0.75), vec3_splat(1.0), entAO);

    MP float minAmbWeight = 0.14 * skyFade * brightDamp;
    MP vec3 minAmb = albedo * (ambTop * minAmbWeight) * entAO;
    MP float shadowFillAmt = mix(0.12, 0.05, goldenFactor);
    MP float shadowAmbAtten = mix(0.24, 0.44, goldenFactor);
    MP vec3 shadowSkyFill = albedo * ambTop * (shadowFillAmt * shadowm * skyFactor) * entAO;
    directSun *= mix(vec3_splat(0.65), vec3_splat(1.0), entAO) * (1.0 - 0.35 * shadowm);
    MP vec3 surfaceCol = (ambientLight + minAmb) * (1.0 - shadowAmbAtten * shadowm) + shadowSkyFill + directSun + torchLight + glintAP1;

    MP vec3 fogAP1 = hFogAP1;
    MP float ca = (allowGroundFog && dimension < 0.5) ? clamp(0.082 * (camPos.y - 63.0), -0.15, 20.0) : 0.0;
    MP vec3 foggedCol = applyAtmosphereEntityPre(
        surfaceCol, camPos, rd, worldPos, hitDist,
        sunDir, activeDir, activeCol, ambTop, horAnti, horSun, midAnti, midSun, skyZenith,
        fogAP1, dayFactor, goldenFactor, nightFactor, hRain, groundFogDensity, ca, sunFresnel, twVis,
        actualFogFactor, isUnderwater, skyFactor, cloudTime, dimension, true
    );

    return applyTonemapPre(foggedCol, exposure, scotopicBase, lightmapUV.x, skyFactor);
}

vec3 evaluateEntityShadingPre(
    vec3 albedoSRGB,
    vec3 worldPos,
    vec3 camPos,
    vec2 lightmapUV,
    float timeOfDay,
    vec3 fogCol,
    float fogFactor,
    float rainFactor,
    vec3 surfaceNormal,
    float exposure,
    float scotopicBase,
    float groundFogDensity,
    float sunFresnel,
    float twVis,
    uvec4 p0,
    uvec4 p1,
    uvec4 p2,
    uvec4 p3,
    float dimension,
    bool allowCloudShadow,
    bool allowGroundFog
) {
    return evaluateEntityShadingPre(
        albedoSRGB,
        worldPos,
        camPos,
        lightmapUV,
        timeOfDay,
        fogCol,
        fogFactor,
        rainFactor,
        surfaceNormal,
        exposure,
        scotopicBase,
        groundFogDensity,
        sunFresnel,
        twVis,
        p0,
        p1,
        p2,
        p3,
        dimension,
        allowCloudShadow,
        allowGroundFog,
        vec3_splat(0.0)
    );
}

vec3 evaluateEntityShadingPre(
    vec3 albedoSRGB,
    vec3 worldPos,
    vec3 camPos,
    vec2 lightmapUV,
    float timeOfDay,
    vec3 fogCol,
    float fogFactor,
    float rainFactor,
    vec3 surfaceNormal,
    float exposure,
    float scotopicBase,
    float groundFogDensity,
    float sunFresnel,
    float twVis,
    uvec4 p0,
    uvec4 p1,
    uvec4 p2,
    uvec4 p3,
    bool allowCloudShadow,
    bool allowGroundFog,
    vec3 glintAP1
) {
    bool isEnd = (abs(fogCol.r - fogCol.b) < 0.06 && (fogCol.r - fogCol.g > 0.15 || (fogCol.g < 0.02 && fogCol.r > 0.04)));
    bool isNether = (fogCol.r > 0.15 && fogCol.b < 0.08) || (fogCol.b > 0.10 && fogCol.g > 0.10 && fogCol.r < 0.15 && lightmapUV.y < 0.05);
    float dimension = isNether ? 1.0 : (isEnd ? 2.0 : 0.0);
    return evaluateEntityShadingPre(
        albedoSRGB,
        worldPos,
        camPos,
        lightmapUV,
        timeOfDay,
        fogCol,
        fogFactor,
        rainFactor,
        surfaceNormal,
        exposure,
        scotopicBase,
        groundFogDensity,
        sunFresnel,
        twVis,
        p0,
        p1,
        p2,
        p3,
        dimension,
        allowCloudShadow,
        allowGroundFog,
        glintAP1
    );
}

vec3 evaluateEntityShadingPre(
    vec3 albedoSRGB,
    vec3 worldPos,
    vec3 camPos,
    vec2 lightmapUV,
    float timeOfDay,
    vec3 fogCol,
    float fogFactor,
    float rainFactor,
    vec3 surfaceNormal,
    float exposure,
    float scotopicBase,
    float groundFogDensity,
    float sunFresnel,
    float twVis,
    uvec4 p0,
    uvec4 p1,
    uvec4 p2,
    uvec4 p3,
    bool allowCloudShadow,
    bool allowGroundFog
) {
    return evaluateEntityShadingPre(
        albedoSRGB,
        worldPos,
        camPos,
        lightmapUV,
        timeOfDay,
        fogCol,
        fogFactor,
        rainFactor,
        surfaceNormal,
        exposure,
        scotopicBase,
        groundFogDensity,
        sunFresnel,
        twVis,
        p0,
        p1,
        p2,
        p3,
        allowCloudShadow,
        allowGroundFog,
        vec3_splat(0.0)
    );
}

#endif
