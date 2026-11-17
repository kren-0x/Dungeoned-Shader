#ifndef LIBRARIES_SKY_GLSL
#define LIBRARIES_SKY_GLSL

#include <libraries/common.glsl>
#include <libraries/color_spaces.glsl>
#include <libraries/brdf.glsl>
#include <libraries/env_pack.glsl>
#include <libraries/luts.glsl>
#ifndef ENTITY_SHADER_ONLY
#include <libraries/clouds.glsl>
#endif

MP vec3 skyGradientPre(
    MP vec3 rd,
    MP vec3 sunDir,
    MP vec3 horAnti,
    MP vec3 horSun,
    MP vec3 midAnti,
    MP vec3 midSun,
    MP vec3 skyZenith,
    MP vec3 sunGlow,
    MP vec3 moonGlow,
    MP float goldenFactor,
    MP float rainFactor
) {
    MP float y = clamp(rd.y, 0.0, 1.0);
    MP float hl = length(rd.xz);
    MP float sunHz = length(sunDir.xz);
    MP vec2 sunDirNormXZ = sunHz > 1e-4 ? sunDir.xz / sunHz : vec2(1.0, 0.0);
    MP float az = hl > 1e-4 ? dot(rd.xz / hl, sunDirNormXZ) : 0.0;
    MP float sunSide = smoothstep(-0.55, 0.90, az);
    MP float goldMix = smoothstep(0.0, 0.70, goldenFactor) * (1.0 - rainFactor);

    MP vec3 horizon = mix(horAnti, horSun, sunSide);
    MP vec3 mid = mix(midAnti, midSun, sunSide);

    MP float horCurve = 1.0 - exp2(-y * mix(4.2, 5.8, goldMix) * 1.44269504);
    MP vec3 col = mix(horizon, mid, horCurve);
    col = mix(col, skyZenith, smoothstep(mix(0.24, 0.08, goldMix), 0.90, y));

    MP float sunAmt = max(dot(rd, sunDir), 0.0);
    MP float moonAmt = max(-dot(rd, sunDir), 0.0);
    MP float sAmt = max(sunAmt, 1e-4);
    MP float s2 = sAmt * sAmt;
    MP float s4 = s2 * s2;
    MP float s8 = s4 * s4;
    MP float s16 = s8 * s8;
    MP float s32 = s16 * s16;
    MP float s64 = s32 * s32;
    MP float s36 = s32 * s4;
    MP float s120 = s64 * s32 * s16 * s8;

    MP float mAmt = max(moonAmt, 1e-4);
    MP float m2 = mAmt * mAmt;
    MP float m6 = m2 * m2 * m2;

    MP float horFade = smoothstep(-0.20, 0.05, rd.y);
    MP float azPos = max(az * 0.5 + 0.5, 1e-4);
    MP float band = exp2(-abs(rd.y) * (6.0 * 1.44269504)) * exp2(1.5 * log2(azPos)) * goldenFactor * (1.0 - rainFactor);
    MP float glowWeight = band * 0.40 + s4 * 0.18 + s16 * 0.32 + s64 * 0.45;

    col = col * (1.0 - clamp(glowWeight * 0.70, 0.0, 0.50) * horFade) + sunGlow * (glowWeight * horFade);
    col += moonGlow * m6 * 0.25 * horFade;

    MP float belowHor = smoothstep(0.02, 0.55, -rd.y);
    MP vec3 lowerSky = horizon * 0.85;
    return mix(col, lowerSky, belowHor);
}

MP vec3 waterFogInScatterPre(MP vec3 rd, MP vec3 activeDir, MP vec3 activeCol, MP vec3 waterFogAP1, MP float dayFactor, MP float goldenFactor, MP float sunFresnel, MP float skyFactor) {
    MP vec3 sunDirInWater = normalize(vec3(activeDir.x * 0.75, max(activeDir.y, 0.15), activeDir.z * 0.75));
    MP float cosSun = dot(rd, sunDirInWater);
    MP float phase = clamp(hgPhase(cosSun, 0.65), 0.05, 8.5);
    MP float sf = clamp(skyFactor, 0.0, 1.0);
    MP float dayLift = mix(0.12, mix(0.75, 1.75, max(dayFactor, goldenFactor * 0.6)), sf);
    MP vec3 fogHue = clamp(waterFogAP1 / max(luminanceAP1(waterFogAP1), 0.04), 0.0, 2.2);
    MP vec3 baseScatter = waterFogAP1 * (dayLift + 0.30 * max(activeDir.y, 0.0) * sf);
    MP vec3 sunShaft = activeCol * fogHue * (max(activeDir.y, 0.0) * sunFresnel * sf * 0.12 * phase);
    return baseScatter + sunShaft;
}

MP vec3 computeWaterAtmospherePre(MP vec3 baseCol, MP vec3 rd, float hitDist, MP vec3 activeDir, MP vec3 activeCol, MP vec3 waterFogAP1, MP float dayFactor, MP float goldenFactor, MP float sunFresnel, MP float fogFactor, MP float skyFactor) {
    MP float dist = min(hitDist, 80.0);
    MP vec3 beta = vec3(0.052, 0.036, 0.032) * 1.44269504;
    MP vec3 tr = exp2(-beta * dist);
    MP vec3 inScatter = waterFogInScatterPre(rd, activeDir, activeCol, waterFogAP1, dayFactor, goldenFactor, sunFresnel, skyFactor);
    MP float fade = clamp(fogFactor, 0.0, 1.0);
    tr = mix(tr, vec3_splat(0.0), fade * fade);
    return baseCol * tr + inScatter * (vec3_splat(1.0) - tr);
}

#if !defined(ENTITY_SHADER_ONLY) && !defined(NO_STARFIELD)
MP vec3 starField(vec3 dir, HP float time) {
    MP vec3 acc = vec3_splat(0.0);
    vec3 pos = normalize(dir);

    for (int i = 0; i < 2; i++) {
        pos = i < 1 ? pos : -pos.xzy;

        float phi = atan_fast(pos.z, pos.x) * 0.212207 + 0.5;
        float theta = acos_fast(clamp(pos.y, -1.0, 1.0)) * 0.63662 - 0.5;
        float mask = step(0.0, phi) * step(phi, 1.0) * step(0.0, theta) * step(theta, 1.0);

        if (mask > 0.5) {
            HP vec2 uv = vec2(phi * 3.0, theta) * 64.0;
            HP vec2 id = floor(uv) + float(i) * 113.0;
            MP float h = hash12(id);
            if (h > 0.94) {
                MP vec2 f = uv - floor(uv);
                MP vec2 sp = vec2_splat(0.3) + 0.4 * vec2(hash12(id + 7.7), hash12(id + 3.1));
                MP float size = 0.10 + 0.08 * hash12(id + 19.3);
                MP vec2 d = abs(f - sp);
                MP float shape = 1.0 - smoothstep(size - 0.03, size, max(d.x, d.y));
                MP float bright = 0.45 + 0.55 * hash12(id + 41.0);
                MP float twinkle = 0.75 + 0.25 * fastSin(fract(time * 0.39788735 + h * 12.732395) * 6.2831853);
                MP vec3 tint = mix(vec3(0.70, 0.82, 1.0), vec3(1.0, 0.88, 0.70), hash12(id + 5.3));
                acc += tint * shape * bright * twinkle;
            }
        }
    }
    return acc;
}

vec4 evaluateSkyPrecomputed(
    vec3 worldPos,
    vec3 camPos,
    float time,
    float cloudTime,
    float isUnderwater,
    float rainFactor,
    MP float exposure,
    MP float scotopic,
    MP vec3 sunDir,
    MP float dayFactor,
    MP float goldenFactor,
    MP float nightFactor,
    MP vec3 horAnti,
    MP vec3 horSun,
    MP vec3 midAnti,
    MP vec3 midSun,
    MP vec3 skyZenith,
    MP vec3 sunGlow,
    MP vec3 moonGlow,
    MP vec3 activeCol,
    MP vec3 cloudLit,
    MP vec3 cloudShade,
    MP vec3 cloudRim,
    MP vec3 sunDiscCol,
    MP vec3 sunRight,
    MP vec3 sunUp,
    MP vec3 fogAP1,
    MP float sunFresnel
) {
    vec3 rd = normalize(worldPos);
    MP vec3 hRd = rd;
    MP vec3 activeDir = sunDir.y >= 0.0 ? sunDir : -sunDir;

    MP vec3 base = skyGradientPre(hRd, sunDir, horAnti, horSun, midAnti, midSun, skyZenith, sunGlow, moonGlow, goldenFactor, rainFactor);
    MP vec3 col = base;

    if (nightFactor > 0.005 && rd.y > 0.0) {
        col += starField(rd, time) * 1.6 * nightFactor * smoothstep(0.0, 0.12, hRd.y) * (1.0 - rainFactor);
    }

    MP float sunDot = dot(hRd, sunDir);
    if (sunDir.y > -0.06 && sunDot > 0.0) {
        MP float sunBox = max(abs(dot(hRd, sunRight)), abs(dot(hRd, sunUp)));
        MP float sunVis = smoothstep(-0.06, 0.04, sunDir.y) * smoothstep(-0.02, 0.02, hRd.y) * (1.0 - rainFactor);
        MP float disc = 1.0 - smoothstep(0.027, 0.031, sunBox);
        col = mix(col, col * 0.25 + sunDiscCol, disc * sunVis);
    }

    if (-sunDir.y > -0.06 && sunDot < 0.0) {
        MP float moonBox = max(abs(dot(hRd, sunRight)), abs(dot(hRd, sunUp)));
        MP float disc = 1.0 - smoothstep(0.020, 0.024, moonBox);
        MP float moonVis = smoothstep(-0.06, 0.04, -sunDir.y) * smoothstep(-0.02, 0.02, hRd.y) * (1.0 - rainFactor) * (1.0 - goldenFactor * 0.65);
        col += MOON_DISC_AP1 * disc * moonVis;
    }

    vec4 cl = traceClouds(camPos, rd, activeDir, cloudLit, cloudShade, sunGlow, time, base, vec3_splat(0.0), rainFactor, false, CLOUD_RANGE, 0.0, cloudRim);
    col = mix(col, cl.rgb, cl.a);

    if (isUnderwater > 0.5) {
        col = computeWaterAtmospherePre(col, hRd, 60.0, activeDir, activeCol, fogAP1, dayFactor, goldenFactor, sunFresnel, 1.0, 1.0);
    }

    HP vec3 lin = AP1ToLinearSRGB(col * exposure);
    if (scotopic > 0.001) {
        HP float luma = dot(lin, vec3(0.2126, 0.7152, 0.0722));
        HP vec3 rodCol = vec3(luma * 0.6, luma * 0.85, luma * 1.25);
        lin = mix(lin, rodCol, scotopic * 0.45);
        HP vec3 scotopicFloor = vec3(0.00048, 0.00048, 0.00065) * scotopic;
        lin = max(lin, scotopicFloor);
    }
#if BGFX_SHADER_TYPE_FRAGMENT
    HP vec3 u = lin / (lin + vec3_splat(0.5));
    MP vec3 dispCol = vec3(
        texture2DLod(s_DungeonedTonemap, vec2(u.r, 0.5), 0.0).r,
        texture2DLod(s_DungeonedTonemap, vec2(u.g, 0.5), 0.0).g,
        texture2DLod(s_DungeonedTonemap, vec2(u.b, 0.5), 0.0).b
    );
#else
    MP vec3 dispCol = tonemapLottes(lin);
#endif
    return vec4(dispCol, 1.0);
}
#endif

#endif
