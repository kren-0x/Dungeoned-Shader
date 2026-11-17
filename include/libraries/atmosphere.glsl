#ifndef LIBRARIES_ATMOSPHERE_GLSL
#define LIBRARIES_ATMOSPHERE_GLSL

#include <libraries/common.glsl>
#include <libraries/color_spaces.glsl>
#include <libraries/env_pack.glsl>
#include <libraries/luts.glsl>
#include <libraries/clouds.glsl>
#include <libraries/sky.glsl>

#define TORCH_COLOR_AP1 vec3(1.60, 0.82, 0.18)
#define TORCH_COLOR_OVERWORLD_AP1 vec3(1.55, 1.12, 0.35)
#define TORCH_COLOR_DIM_AP1 vec3(1.60, 0.82, 0.18)
#define BOUNCE_AMB_TINT_AP1 vec3(0.3257843, 0.4387315, 0.1713931)
#define FOLIAGE_SSS_TINT_AP1 vec3(0.6527128, 0.7720550, 0.2496587)
#define DAY_MIST_BASE_AP1 vec3(0.2837826, 0.3911067, 0.6680610)
#define WATER_SCATTER_AP1 vec3(0.0815792, 0.1707282, 0.2824470)
#define GOLD_WATER_TINT_AP1 vec3(0.6942758, 0.2877775, 0.0581171)
#define NETHER_AMB_BASE_AP1 vec3(0.085, 0.038, 0.020)
#define NETHER_AMB_BOT_AP1 vec3(0.055, 0.024, 0.012)
#define END_AMB_BASE_AP1 vec3(0.135, 0.117, 0.171)
#define END_AMB_BOT_AP1 vec3(0.065, 0.055, 0.085)

MP vec3 getSunGlowPre(MP float sunY, MP float goldenFactor, MP float rainFactor) {
    return mix(DAY_SUN_GLOW_AP1, GOLD_SUN_GLOW_AP1, goldenFactor)
         * mix(1.20, 1.85, goldenFactor)
         * smoothstep(-0.16, 0.12, sunY) * (1.0 - rainFactor * 0.92);
}

MP vec3 getMoonGlowPre(MP float nightFactor, MP float rainFactor) {
    return MOON_GLOW_BASE_AP1 * nightFactor * 0.25 * (1.0 - rainFactor * 0.92);
}

void getCloudColorsPre(
    MP float sunY,
    MP float dayFactor,
    MP float goldenFactor,
    MP float rainFactor,
    MP float twVis,
    out MP vec3 cloudLit,
    out MP vec3 cloudShade,
    out MP vec3 cloudRim
) {
    MP vec3 litBase = mix(NIGHT_CLOUD_LIT_AP1, DAY_CLOUD_LIT_AP1, dayFactor);
    MP vec3 shadeBase = mix(NIGHT_CLOUD_SHADE_AP1, DAY_CLOUD_SHADE_AP1, dayFactor);

    MP vec3 goldCloudLit = GOLD_CLOUD_LIT_AP1 * mix(0.45, 1.35, twVis);
    MP vec3 goldCloudShade = GOLD_CLOUD_SHADE_AP1 * mix(0.40, 1.10, twVis);

    MP vec3 clearCloudLit = mix(litBase, goldCloudLit, goldenFactor);
    MP vec3 clearCloudShade = mix(shadeBase, goldCloudShade, goldenFactor);

    MP vec3 rainCloudLit = RAIN_CLOUD_LIT_AP1 * mix(0.70, 1.35, dayFactor);
    MP vec3 rainCloudShade = RAIN_CLOUD_SHADE_AP1 * mix(0.60, 1.20, dayFactor);

    cloudLit = mix(clearCloudLit, rainCloudLit, rainFactor);
    cloudShade = mix(clearCloudShade, rainCloudShade, rainFactor);

    MP vec3 sunTint = fastFromSRGB(mix(vec3(1.0, 0.98, 0.92), vec3(1.0, 0.65, 0.22), goldenFactor))
                    * mix(2.4, 3.8, goldenFactor) * smoothstep(-0.14, 0.06, sunY);
    MP vec3 moonTint = MOON_TINT_BASE_AP1 * smoothstep(-0.04, 0.12, -sunY) * (1.0 - goldenFactor * 0.75);
    cloudRim = (sunTint + moonTint) * (1.0 - rainFactor * 0.92);
}

MP vec3 getSkyPre(
    vec3 ro,
    vec3 rd,
    MP vec3 sunDir,
    MP vec3 activeDir,
    MP vec3 horAnti,
    MP vec3 horSun,
    MP vec3 midAnti,
    MP vec3 midSun,
    MP vec3 skyZenith,
    MP vec3 sunGlow,
    MP vec3 moonGlow,
    MP vec3 cloudLit,
    MP vec3 cloudShade,
    MP vec3 cloudRim,
    float cloudTime,
    MP float goldenFactor,
    MP float rainFactor,
    bool lite
) {
    MP vec3 base = skyGradientPre(rd, sunDir, horAnti, horSun, midAnti, midSun, skyZenith, sunGlow, moonGlow, goldenFactor, rainFactor);
    vec4 cl = traceClouds(ro, rd, activeDir, cloudLit, cloudShade, sunGlow, cloudTime, base, vec3_splat(0.0), rainFactor, lite, CLOUD_RANGE, 0.0, cloudRim);
    return mix(base, cl.rgb, cl.a);
}

MP vec3 applyAtmosphereEntityPre(
    MP vec3 col,
    vec3 ro,
    vec3 rd,
    vec3 worldPos,
    float hitDist,
    MP vec3 sunDir,
    MP vec3 activeDir,
    MP vec3 activeCol,
    MP vec3 ambTop,
    MP vec3 horAnti,
    MP vec3 horSun,
    MP vec3 midAnti,
    MP vec3 midSun,
    MP vec3 skyZenith,
    MP vec3 fogAP1,
    MP float dayFactor,
    MP float goldenFactor,
    MP float nightFactor,
    MP float rainFactor,
    MP float groundFogDensity,
    MP float ca,
    MP float sunFresnel,
    float twVis,
    MP float fogFactor,
    MP float isUnderwater,
    MP float skyFactor,
    float cloudTime,
    float dimension,
    bool allowClouds
) {
    if (isUnderwater > 0.5) {
        return computeWaterAtmospherePre(col, rd, hitDist, activeDir, activeCol, fogAP1, dayFactor, goldenFactor, sunFresnel, fogFactor, skyFactor);
    }

    MP float dist = min(hitDist, 500.0);
    MP float sunDot = max(dot(rd, sunDir), 0.0);
    MP float sunForward = sunDot * sunDot * sunDot;
    MP vec3 sunGlow = getSunGlowPre(sunDir.y, goldenFactor, rainFactor);
    MP vec3 moonGlow = getMoonGlowPre(nightFactor, rainFactor);

    MP vec3 baseCol = col;
    if (dimension < 0.5 && hitDist > 10.0) {
        MP float cb = clamp(0.082 * ((ro.y + rd.y * dist) - 63.0), -0.15, 20.0);
        MP float cdy = cb - ca;
        MP float groundOpt = abs(cdy) > 1e-3
            ? groundFogDensity * dist * (exp2(-ca * 1.44269504) - exp2(-cb * 1.44269504)) / cdy
            : groundFogDensity * dist * exp2(-ca * 1.44269504);
        MP float outdoorGround = smoothstep(0.30, 0.85, skyFactor);
        MP float nearClear = smoothstep(35.0, 95.0, hitDist);
        groundOpt *= outdoorGround * nearClear;
        MP float groundTrans = exp2(-max(groundOpt, 0.0) * 1.44269504);

        MP vec3 skyHorizon = mix(mix(NIGHT_HOR_AP1, DAY_HOR_AP1, dayFactor), GREY_HOR_AP1 * mix(0.22, 0.80, dayFactor), rainFactor);
        MP vec3 dayMistCol = mix(DAY_MIST_BASE_AP1, skyHorizon * 0.82, 0.45);
        MP vec3 groundFogCol = mix(skyHorizon * 0.72, dayMistCol, dayFactor * (1.0 - rainFactor));
        MP float goldMix = smoothstep(0.0, 0.70, goldenFactor) * (1.0 - rainFactor);
        if (goldMix > 0.001) {
            MP float hl = length(rd.xz);
            MP float sunHz = length(sunDir.xz);
            MP vec2 sunDirNormXZ = sunHz > 1e-4 ? sunDir.xz / sunHz : vec2(1.0, 0.0);
            MP float az = hl > 1e-4 ? dot(rd.xz / hl, sunDirNormXZ) : 0.0;
            MP float sunAlign = smoothstep(-0.6, 1.0, az);
            MP vec3 goldMist = mix(horAnti * 0.95, horSun * 1.10, sunAlign) + sunGlow * (0.15 + 0.35 * sunForward);
            groundFogCol = mix(groundFogCol, goldMist, goldMix);
        }
        groundFogCol = mix(groundFogCol, ambTop * 0.82, rainFactor);
        baseCol = mix(groundFogCol, baseCol, groundTrans);
    }

    MP float density = mix(0.00020 * (1.0 - 0.3 * goldenFactor), 0.005, rainFactor);
    MP float falloff = mix(0.015, 0.005, rainFactor);
    if (dimension > 0.5) {
        if (dimension < 1.5) {
            density = 0.0035;
            falloff = 0.0;
        } else {
            density = 0.00010;
            falloff = 0.0;
        }
    }
    MP float k = falloff * rd.y;
    MP float optical = abs(k) > 1e-4
        ? density * (1.0 - exp2(clamp(-k * dist, -10.0, 10.0) * 1.44269504)) / k
        : density * dist;
    if (dimension < 0.5) {
        optical *= mix(1.0, 2.2, rainFactor);
    }
    MP float transmittance = exp2(-max(optical, 0.0) * 1.44269504);

    MP float cosSun = dot(rd, activeDir);
    MP float miePhase = mix(hgPhase(cosSun, 0.68), hgPhase(cosSun, -0.2), 0.18);

    MP vec3 hazeRd = normalize(vec3(rd.x, max(rd.y, 0.0) + 0.001, rd.z));
    MP vec3 sunsetHaze = (sunGlow * 0.45 + horSun * 0.35) * (0.25 + 0.45 * sunForward) * goldenFactor * (1.0 - rainFactor);
    MP vec3 inScatter;
    MP vec3 skyTarget;
    if (dimension > 0.5) {
        if (dimension < 1.5) {
            inScatter = fogAP1 * 1.10;
            skyTarget = fogAP1;
        } else {
            inScatter = vec3_splat(0.0);
            skyTarget = vec3_splat(0.0);
        }
    } else {
        skyTarget = skyGradientPre(hazeRd, sunDir, horAnti, horSun, midAnti, midSun, skyZenith, sunGlow, moonGlow, goldenFactor, rainFactor);
        inScatter = skyTarget
                  + activeCol * miePhase * 0.14 * (1.0 - rainFactor * 0.8)
                  + sunsetHaze;
    }

    MP float borderFade;
    if (dimension > 0.5) {
        borderFade = (dimension < 1.5) ? smoothstep(0.10, 0.85, fogFactor) : smoothstep(0.40, 0.92, fogFactor);
    } else {
        borderFade = smoothstep(0.55, 0.96, fogFactor);
    }
    MP float rainFog = (dimension < 0.5) ? (rainFactor * 0.50 * smoothstep(10.0, 70.0, hitDist)) : 0.0;
    MP float fade = clamp(borderFade + rainFog, 0.0, 1.0);
    transmittance = mix(transmittance, 0.0, fade);
    MP float outdoorAtm = dimension > 0.5 ? 1.0 : smoothstep(0.04, 0.35, skyFactor);
    MP vec3 caveFogTarget = (dimension > 1.5) ? inScatter * 0.25 : fogAP1 * 0.35;
    inScatter = mix(caveFogTarget, inScatter, outdoorAtm);
    inScatter = mix(inScatter, skyTarget, borderFade * outdoorAtm);

    MP vec3 foggedCol = baseCol * transmittance + inScatter * (1.0 - transmittance);

    if (allowClouds && hitDist > 2.0 && dimension < 0.5 && outdoorAtm > 0.01) {
        bool canHitClouds = false;
        if (ro.y < CLOUD_BASE) {
            canHitClouds = (rd.y > max((CLOUD_BASE - ro.y) * (1.0 / CLOUD_RANGE), 1e-4)) && (worldPos.y > CLOUD_BASE || borderFade > 0.001);
        } else if (ro.y > CLOUD_TOP) {
            canHitClouds = (rd.y < -max((ro.y - CLOUD_TOP) * (1.0 / CLOUD_RANGE), 1e-4)) && (worldPos.y < CLOUD_TOP || borderFade > 0.001);
        } else {
            canHitClouds = true;
        }
        if (canHitClouds) {
            MP vec3 cloudLit;
            MP vec3 cloudShade;
            MP vec3 cloudRim;
            getCloudColorsPre(sunDir.y, dayFactor, goldenFactor, rainFactor, twVis, cloudLit, cloudShade, cloudRim);
            vec4 cloud = traceClouds(ro, rd, activeDir, cloudLit, cloudShade, sunGlow, cloudTime, skyTarget, vec3_splat(0.0), rainFactor, true, hitDist, borderFade, cloudRim);
            foggedCol = mix(foggedCol, cloud.rgb, cloud.a);
        }
    }

    return foggedCol;
}

MP vec3 applyAtmosphereEntityPre(
    MP vec3 col,
    vec3 ro,
    vec3 rd,
    float hitDist,
    MP vec3 sunDir,
    MP vec3 activeDir,
    MP vec3 activeCol,
    MP vec3 ambTop,
    MP vec3 horAnti,
    MP vec3 horSun,
    MP vec3 midAnti,
    MP vec3 midSun,
    MP vec3 skyZenith,
    MP vec3 fogAP1,
    MP float dayFactor,
    MP float goldenFactor,
    MP float nightFactor,
    MP float rainFactor,
    MP float groundFogDensity,
    MP float ca,
    MP float sunFresnel,
    MP float fogFactor,
    MP float isUnderwater,
    MP float skyFactor,
    float cloudTime,
    float dimension
) {
    return applyAtmosphereEntityPre(
        col, ro, rd, ro + rd * hitDist, hitDist, sunDir, activeDir, activeCol, ambTop, horAnti, horSun,
        midAnti, midSun, skyZenith, fogAP1, dayFactor, goldenFactor, nightFactor, rainFactor,
        groundFogDensity, ca, sunFresnel, 0.5, fogFactor, isUnderwater, skyFactor, cloudTime, dimension, false
    );
}

MP vec3 applyAtmosphereEntityPre(
    MP vec3 col,
    vec3 ro,
    vec3 rd,
    float hitDist,
    MP vec3 sunDir,
    MP vec3 activeDir,
    MP vec3 activeCol,
    MP vec3 ambTop,
    MP vec3 horAnti,
    MP vec3 horSun,
    MP vec3 midAnti,
    MP vec3 midSun,
    MP vec3 skyZenith,
    MP vec3 fogAP1,
    MP float dayFactor,
    MP float goldenFactor,
    MP float nightFactor,
    MP float rainFactor,
    MP float groundFogDensity,
    MP float ca,
    MP float sunFresnel,
    MP float fogFactor,
    MP float isUnderwater,
    MP float skyFactor,
    float cloudTime
) {
    return applyAtmosphereEntityPre(
        col, ro, rd, hitDist, sunDir, activeDir, activeCol, ambTop, horAnti, horSun,
        midAnti, midSun, skyZenith, fogAP1, dayFactor, goldenFactor, nightFactor, rainFactor,
        groundFogDensity, ca, sunFresnel, fogFactor, isUnderwater, skyFactor, cloudTime, 0.0
    );
}

#ifndef ENTITY_SHADER_ONLY
MP vec3 applyAtmospherePre(
    MP vec3 col,
    vec3 ro,
    vec3 rd,
    vec3 worldPos,
    float hitDist,
    MP vec3 sunDir,
    MP vec3 activeDir,
    MP vec3 activeCol,
    MP vec3 ambTop,
    MP vec3 horAnti,
    MP vec3 horSun,
    MP vec3 midAnti,
    MP vec3 midSun,
    MP vec3 skyZenith,
    MP vec3 fogAP1,
    MP float dayFactor,
    MP float goldenFactor,
    MP float nightFactor,
    MP float rainFactor,
    MP float groundFogDensity,
    MP float ca,
    MP float sunFresnel,
    MP float twVis,
    MP float fogFactor,
    MP float isUnderwater,
    MP float skyFactor,
    float cloudTime,
    float dimension,
    bool allowClouds
) {
    if (isUnderwater > 0.5) {
        return computeWaterAtmospherePre(col, rd, hitDist, activeDir, activeCol, fogAP1, dayFactor, goldenFactor, sunFresnel, fogFactor, skyFactor);
    }

    MP float dist = min(hitDist, 500.0);
    MP float sunDot = max(dot(rd, sunDir), 0.0);
    MP float sunForward = sunDot * sunDot * sunDot;
    MP vec3 sunGlow = getSunGlowPre(sunDir.y, goldenFactor, rainFactor);
    MP vec3 moonGlow = getMoonGlowPre(nightFactor, rainFactor);

    MP vec3 baseCol = col;
    if (dimension < 0.5 && hitDist > 10.0) {
        MP float cb = clamp(0.082 * ((ro.y + rd.y * dist) - 63.0), -0.15, 20.0);
        MP float cdy = cb - ca;
        MP float groundOpt = abs(cdy) > 1e-3
            ? groundFogDensity * dist * (exp2(-ca * 1.44269504) - exp2(-cb * 1.44269504)) / cdy
            : groundFogDensity * dist * exp2(-ca * 1.44269504);
        MP float outdoorGround = smoothstep(0.30, 0.85, skyFactor);
        MP float nearClear = smoothstep(35.0, 95.0, hitDist);
        groundOpt *= outdoorGround * nearClear;
        MP float groundTrans = exp2(-max(groundOpt, 0.0) * 1.44269504);

        MP vec3 skyHorizon = mix(mix(NIGHT_HOR_AP1, DAY_HOR_AP1, dayFactor), GREY_HOR_AP1 * mix(0.22, 0.80, dayFactor), rainFactor);
        MP vec3 dayMistCol = mix(DAY_MIST_BASE_AP1, skyHorizon * 0.82, 0.45);
        MP vec3 groundFogCol = mix(skyHorizon * 0.72, dayMistCol, dayFactor * (1.0 - rainFactor));
        MP float goldMix = smoothstep(0.0, 0.70, goldenFactor) * (1.0 - rainFactor);
        if (goldMix > 0.001) {
            MP float hl = length(rd.xz);
            MP float sunHz = length(sunDir.xz);
            MP vec2 sunDirNormXZ = sunHz > 1e-4 ? sunDir.xz / sunHz : vec2(1.0, 0.0);
            MP float az = hl > 1e-4 ? dot(rd.xz / hl, sunDirNormXZ) : 0.0;
            MP float sunAlign = smoothstep(-0.6, 1.0, az);
            MP vec3 goldMist = mix(horAnti * 0.95, horSun * 1.10, sunAlign) + sunGlow * (0.15 + 0.35 * sunForward);
            groundFogCol = mix(groundFogCol, goldMist, goldMix);
        }
        groundFogCol = mix(groundFogCol, ambTop * 0.82, rainFactor);
        baseCol = mix(groundFogCol, baseCol, groundTrans);
    }

    MP float density = mix(0.00020 * (1.0 - 0.3 * goldenFactor), 0.005, rainFactor);
    MP float falloff = mix(0.015, 0.005, rainFactor);
    if (dimension > 0.5) {
        if (dimension < 1.5) {
            density = 0.0035;
            falloff = 0.0;
        } else {
            density = 0.00010;
            falloff = 0.0;
        }
    }
    MP float k = falloff * rd.y;
    MP float optical = abs(k) > 1e-4
        ? density * (1.0 - exp2(clamp(-k * dist, -10.0, 10.0) * 1.44269504)) / k
        : density * dist;
    if (dimension < 0.5) {
        optical *= mix(1.0, 2.2, rainFactor);
    }
    MP float transmittance = exp2(-max(optical, 0.0) * 1.44269504);

    MP float cosSun = dot(rd, activeDir);
    MP float miePhase = mix(hgPhase(cosSun, 0.68), hgPhase(cosSun, -0.2), 0.18);

    MP vec3 hazeRd = normalize(vec3(rd.x, max(rd.y, 0.0) + 0.001, rd.z));
    MP vec3 sunsetHaze = (sunGlow * 0.45 + horSun * 0.35) * (0.25 + 0.45 * sunForward) * goldenFactor * (1.0 - rainFactor);
    MP vec3 inScatter;
    MP vec3 skyTarget;
    if (dimension > 0.5) {
        if (dimension < 1.5) {
            inScatter = fogAP1 * 1.10;
            skyTarget = fogAP1;
        } else {
            inScatter = vec3_splat(0.0);
            skyTarget = vec3_splat(0.0);
        }
    } else {
        skyTarget = skyGradientPre(hazeRd, sunDir, horAnti, horSun, midAnti, midSun, skyZenith, sunGlow, moonGlow, goldenFactor, rainFactor);
        inScatter = skyTarget
                  + activeCol * miePhase * 0.14 * (1.0 - rainFactor * 0.8)
                  + sunsetHaze;
    }

    MP float borderFade;
    if (dimension > 0.5) {
        borderFade = (dimension < 1.5) ? smoothstep(0.10, 0.85, fogFactor) : smoothstep(0.40, 0.92, fogFactor);
    } else {
        borderFade = smoothstep(0.55, 0.96, fogFactor);
    }
    MP float rainFog = (dimension < 0.5) ? (rainFactor * 0.50 * smoothstep(10.0, 70.0, hitDist)) : 0.0;
    MP float fade = clamp(borderFade + rainFog, 0.0, 1.0);
    transmittance = mix(transmittance, 0.0, fade);
    MP float outdoorAtm = dimension > 0.5 ? 1.0 : smoothstep(0.04, 0.35, skyFactor);
    MP vec3 caveFogTarget = (dimension > 1.5) ? inScatter * 0.25 : fogAP1 * 0.35;
    inScatter = mix(caveFogTarget, inScatter, outdoorAtm);
    inScatter = mix(inScatter, skyTarget, borderFade * outdoorAtm);

    MP vec3 foggedCol = baseCol * transmittance + inScatter * (1.0 - transmittance);

    if (allowClouds && hitDist > 2.0 && dimension < 0.5 && outdoorAtm > 0.01) {
        bool canHitClouds = false;
        if (ro.y < CLOUD_BASE) {
            canHitClouds = (rd.y > max((CLOUD_BASE - ro.y) * (1.0 / CLOUD_RANGE), 1e-4)) && (worldPos.y > CLOUD_BASE || borderFade > 0.001);
        } else if (ro.y > CLOUD_TOP) {
            canHitClouds = (rd.y < -max((ro.y - CLOUD_TOP) * (1.0 / CLOUD_RANGE), 1e-4)) && (worldPos.y < CLOUD_TOP || borderFade > 0.001);
        } else {
            canHitClouds = true;
        }
        if (canHitClouds) {
            MP vec3 cloudLit;
            MP vec3 cloudShade;
            MP vec3 cloudRim;
            getCloudColorsPre(sunDir.y, dayFactor, goldenFactor, rainFactor, twVis, cloudLit, cloudShade, cloudRim);
            vec4 cloud = traceClouds(ro, rd, activeDir, cloudLit, cloudShade, sunGlow, cloudTime, skyTarget, vec3_splat(0.0), rainFactor, false, hitDist, borderFade, cloudRim);
            foggedCol = mix(foggedCol, cloud.rgb, cloud.a);
        }
    }

    return foggedCol;
}
#endif

#endif
