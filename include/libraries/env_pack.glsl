#ifndef LIBRARIES_ENV_PACK_GLSL
#define LIBRARIES_ENV_PACK_GLSL

#include <libraries/common.glsl>
#include <libraries/color_spaces.glsl>
#include <libraries/brdf.glsl>
#include <libraries/luts.glsl>

#define CLOUD_BASE 142.0
#define CLOUD_TOP 154.0
#define CLOUD_CELL 12.0
#define CLOUD_RANGE 800.0

#define SUN_PATH_YAW   15.0
#define SUN_PATH_TILT  31.0

#define MOON_COL_BASE_AP1 vec3(0.1047986, 0.1221002, 0.3194031)
#define MOON_TINT_BASE_AP1 vec3(0.1347411, 0.1569860, 0.4106611)
#define NIGHT_ZENITH_AP1 vec3(0.0002229, 0.0002091, 0.0025249)
#define DAY_ZENITH_AP1 vec3(0.1179790, 0.1952481, 0.7990671)
#define NIGHT_MID_AP1 vec3(0.0010914, 0.0009527, 0.0098760)
#define DAY_MID_AP1 vec3(0.2554336, 0.4125511, 0.8810840)
#define NIGHT_HOR_AP1 vec3(0.0030463, 0.0030828, 0.0228698)
#define DAY_HOR_AP1 vec3(0.4828368, 0.6450030, 0.8750272)
#define GOLD_ZEN_LOW_AP1 vec3(0.012, 0.018, 0.065)
#define GOLD_ZEN_HI_AP1 vec3(0.24, 0.28, 0.62)
#define GREY_ZEN_AP1 vec3(0.06, 0.07, 0.09)
#define GREY_MID_AP1 vec3(0.09, 0.10, 0.12)
#define GREY_HOR_AP1 vec3(0.12, 0.13, 0.16)
#define GOLD_SUN_HOR_AP1 vec3(1.25, 0.65, 0.18)
#define GOLD_SUN_MID_AP1 vec3(0.95, 0.62, 0.32)
#define GOLD_ANTI_HOR_AP1 vec3(0.72, 0.38, 0.24)
#define GOLD_ANTI_MID_AP1 vec3(0.35, 0.32, 0.52)
#define DAY_SUN_GLOW_AP1 vec3(1.15, 1.15, 1.15)
#define GOLD_SUN_GLOW_AP1 vec3(1.85, 1.25, 0.45)
#define MOON_GLOW_BASE_AP1 vec3(0.3617961, 0.4489561, 0.8325224)
#define AMB_BLUE_AP1 vec3(0.1466167, 0.2072821, 0.8564952)
#define AMB_NIGHT_TOP_AP1 vec3(0.0143071, 0.0179564, 0.0831108)
#define GOLD_AMB_TOP_AP1 vec3(0.48, 0.28, 0.14)
#define AMB_NIGHT_BOT_AP1 vec3(0.0090284, 0.0082466, 0.0279808)
#define AMB_DAY_BOT_AP1 vec3(0.1082397, 0.1178486, 0.0926115)
#define GOLD_AMB_BOT_AP1 vec3(0.14, 0.06, 0.02)
#define RAIN_AMB_TOP_AP1 vec3(0.1486887, 0.1630844, 0.2271110)
#define RAIN_AMB_BOT_AP1 vec3(0.0705828, 0.0805795, 0.1136890)
#define DAY_CLOUD_LIT_AP1 vec3(2.3182111, 2.3445830, 2.3921008)
#define DAY_CLOUD_SHADE_AP1 vec3(0.4288735, 0.6216078, 1.2580210)
#define NIGHT_CLOUD_LIT_AP1 vec3(0.0556774, 0.0617335, 0.1523993)
#define NIGHT_CLOUD_SHADE_AP1 vec3(0.0057734, 0.0060234, 0.0262647)
#define GOLD_CLOUD_LIT_AP1 vec3(2.80, 1.65, 0.42)
#define GOLD_CLOUD_SHADE_AP1 vec3(0.135, 0.105, 0.185)
#define RAIN_CLOUD_LIT_AP1 vec3(0.16, 0.175, 0.21)
#define RAIN_CLOUD_SHADE_AP1 vec3(0.08, 0.088, 0.11)
#define MOON_DISC_AP1 vec3(1.1070620, 1.2530960, 1.5509351)
#define CAVE_AMB_AP1 vec3(0.025, 0.027, 0.034)

mat2 rmat2(float t) {
    float sint = sin(t);
    float cost = cos(t);
    return mtxFromRows(vec2(cost, -sint), vec2(sint, cost));
}

float degToRad(float t) {
    return 0.0174533 * t;
}

void calculateSunParams(float timeOfDay, out vec3 sunDir, out vec3 moonDir) {
    float t = 2.0 * PI * timeOfDay;
    vec3 sDir = vec3(-sin(t), cos(t), 0.0);
    sDir.yz = mul(rmat2(-degToRad(SUN_PATH_TILT)), sDir.yz);
    sDir.xz = mul(rmat2(degToRad(SUN_PATH_YAW)), sDir.xz);
    sunDir = normalize(sDir);
    moonDir = -sunDir;
}

struct EnvLight {
    vec3 sunDir;
    vec3 moonDir;
    vec3 activeDir;
    vec3 activeCol;
    vec3 skyZenith;
    vec3 skyMid;
    vec3 skyHorizon;
    vec3 twSunHor;
    vec3 twSunMid;
    vec3 twAntiHor;
    vec3 twAntiMid;
    vec3 sunGlow;
    vec3 moonGlow;
    vec3 ambTop;
    vec3 ambBot;
    vec3 cloudLit;
    vec3 cloudShade;
    vec3 cloudRim;
    float dayFactor;
    float goldenFactor;
    float nightFactor;
    float rainFactor;
};

EnvLight getEnv(float time, vec3 sunDirIn, vec3 moonDirIn, float rainFactor) {
    EnvLight env;
    env.sunDir = sunDirIn;
    env.moonDir = moonDirIn;
    env.rainFactor = rainFactor;

    float sunH = env.sunDir.y;
    env.dayFactor = smoothstep(-0.08, 0.28, sunH);
    float gfUp = smoothstep(-0.22, 0.02, sunH);
    float gfDown = 1.0 - smoothstep(0.10, 0.36, sunH);
    env.goldenFactor = gfUp * gfDown * (1.0 - rainFactor * 0.9);
    env.nightFactor = (1.0 - smoothstep(-0.22, 0.10, sunH)) * (1.0 - rainFactor * 0.5);
    float twVis = smoothstep(-0.18, 0.03, sunH);

    vec3 sunBase = fromSRGB(mix(vec3(1.0, 0.98, 0.92), vec3(1.0, 0.65, 0.22), env.goldenFactor));
    vec3 sunCol = sunBase * mix(3.5, 3.6, env.goldenFactor) * smoothstep(-0.06, 0.06, sunH);
    vec3 moonCol = MOON_COL_BASE_AP1 * smoothstep(-0.04, 0.10, -sunH) * (1.0 - env.goldenFactor * 0.75);

    vec3 sunTint = sunBase * mix(2.4, 3.8, env.goldenFactor) * smoothstep(-0.14, 0.06, sunH);
    vec3 moonTint = MOON_TINT_BASE_AP1 * smoothstep(-0.04, 0.12, -sunH) * (1.0 - env.goldenFactor * 0.75);
    env.cloudRim = (sunTint + moonTint) * (1.0 - rainFactor * 0.92);

    sunCol *= mix(1.0, 0.04, rainFactor);
    moonCol *= mix(1.0, 0.06, rainFactor);

    if (sunH >= 0.0) {
        env.activeDir = env.sunDir;
        env.activeCol = sunCol;
    } else {
        env.activeDir = env.moonDir;
        env.activeCol = moonCol;
    }

    vec3 zenith = mix(NIGHT_ZENITH_AP1, DAY_ZENITH_AP1, env.dayFactor);
    vec3 mid = mix(NIGHT_MID_AP1, DAY_MID_AP1, env.dayFactor);
    vec3 horizon = mix(NIGHT_HOR_AP1, DAY_HOR_AP1, env.dayFactor);

    vec3 goldZenith = mix(GOLD_ZEN_LOW_AP1, GOLD_ZEN_HI_AP1, twVis);
    env.skyZenith = mix(zenith, goldZenith, env.goldenFactor * 0.85);
    env.skyMid = mid;
    env.skyHorizon = horizon;

    vec3 greyZenith = GREY_ZEN_AP1 * mix(0.20, 1.0, env.dayFactor);
    vec3 greyMid = GREY_MID_AP1 * mix(0.22, 1.0, env.dayFactor);
    vec3 greyHor = GREY_HOR_AP1 * mix(0.25, 1.0, env.dayFactor);

    env.skyZenith = mix(env.skyZenith, greyZenith, rainFactor);
    env.skyMid = mix(env.skyMid, greyMid, rainFactor);
    env.skyHorizon = mix(env.skyHorizon, greyHor, rainFactor);

    vec3 goldSunHor = GOLD_SUN_HOR_AP1 * mix(0.28, 1.0, twVis);
    vec3 goldSunMid = GOLD_SUN_MID_AP1 * mix(0.25, 1.0, twVis);
    vec3 goldAntiHor = GOLD_ANTI_HOR_AP1 * mix(0.25, 1.0, twVis);
    vec3 goldAntiMid = GOLD_ANTI_MID_AP1 * mix(0.22, 1.0, twVis);

    env.twSunHor = mix(goldSunHor, greyHor, rainFactor);
    env.twSunMid = mix(goldSunMid, greyMid, rainFactor);
    env.twAntiHor = mix(goldAntiHor, greyHor, rainFactor);
    env.twAntiMid = mix(goldAntiMid, greyMid, rainFactor);

    env.sunGlow = mix(DAY_SUN_GLOW_AP1, GOLD_SUN_GLOW_AP1, env.goldenFactor)
                * mix(1.20, 1.85, env.goldenFactor)
                * smoothstep(-0.16, 0.12, sunH) * (1.0 - rainFactor * 0.92);
    env.moonGlow = MOON_GLOW_BASE_AP1 * env.nightFactor * 0.25 * (1.0 - rainFactor * 0.92);

    vec3 ambDay = mix(AMB_NIGHT_TOP_AP1, mix(mix(env.skyMid, env.skyZenith, 0.35), AMB_BLUE_AP1, 0.55), env.dayFactor);
    vec3 clearAmbTop = mix(ambDay, GOLD_AMB_TOP_AP1 * mix(0.40, 1.0, twVis), env.goldenFactor * 0.85);
    vec3 clearAmbBot = mix(AMB_NIGHT_BOT_AP1, AMB_DAY_BOT_AP1, env.dayFactor);
    clearAmbBot = mix(clearAmbBot, GOLD_AMB_BOT_AP1 * mix(0.40, 1.0, twVis), env.goldenFactor * 0.90);

    vec3 rainAmbTop = RAIN_AMB_TOP_AP1 * mix(0.45, 1.30, env.dayFactor);
    vec3 rainAmbBot = RAIN_AMB_BOT_AP1 * mix(0.35, 1.00, env.dayFactor);

    env.ambTop = mix(clearAmbTop, rainAmbTop, rainFactor);
    env.ambBot = mix(clearAmbBot, rainAmbBot, rainFactor);

    vec3 litBase = mix(NIGHT_CLOUD_LIT_AP1, DAY_CLOUD_LIT_AP1, env.dayFactor);
    vec3 shadeBase = mix(NIGHT_CLOUD_SHADE_AP1, DAY_CLOUD_SHADE_AP1, env.dayFactor);

    vec3 goldCloudLit = GOLD_CLOUD_LIT_AP1 * mix(0.35, 1.0, twVis);
    vec3 goldCloudShade = GOLD_CLOUD_SHADE_AP1 * mix(0.35, 1.0, twVis);

    vec3 clearCloudLit = mix(litBase, goldCloudLit, env.goldenFactor);
    vec3 clearCloudShade = mix(shadeBase, goldCloudShade, env.goldenFactor);

    vec3 rainCloudLit = RAIN_CLOUD_LIT_AP1 * mix(0.18, 1.0, env.dayFactor);
    vec3 rainCloudShade = RAIN_CLOUD_SHADE_AP1 * mix(0.14, 1.0, env.dayFactor);

    env.cloudLit = mix(clearCloudLit, rainCloudLit, rainFactor);
    env.cloudShade = mix(clearCloudShade, rainCloudShade, rainFactor);

    return env;
}

EnvLight getEnv(float time, vec3 sunDirIn, vec3 moonDirIn) {
    return getEnv(time, sunDirIn, moonDirIn, 0.0);
}

float meterLuminance(EnvLight env) {
    float baseSkyL = 0.5 * (luminanceAP1(env.skyMid) + luminanceAP1(env.skyHorizon));
    float twSkyL = 0.5 * (luminanceAP1(env.twSunHor) + luminanceAP1(env.twAntiMid));
    float skyL = mix(baseSkyL, max(baseSkyL, twSkyL), env.goldenFactor * (1.0 - env.rainFactor));
    float irradiance = luminanceAP1(env.activeCol) * max(env.activeDir.y, 0.10 * env.goldenFactor) + luminanceAP1(env.ambTop) * 0.6;
    return mix(0.2 * irradiance, skyL, 0.35) + 1e-4;
}

float evalExposure(float sceneL) {
    float raw = sqrt(sqrt(0.42 / max(sceneL, 1e-4)));
    float d = raw - 1.0;
    return d >= 0.0 ? (1.0 + d / (1.0 + 2.0 * d)) : (1.0 + d / (1.0 - 2.5 * d));
}

void packEnvVaryings(
    float timeOfDay,
    float rainFactor,
    out uvec4 p0,
    out uvec4 p1,
    out uvec4 p2,
    out uvec4 p3,
    out float exposure,
    out float scotopicBase,
    out float groundFogDensity,
    out float sunFresnel,
    out float twVis
) {
    vec3 sunDir;
    vec3 moonDir;
    calculateSunParams(timeOfDay, sunDir, moonDir);
    EnvLight env = getEnv(0.0, sunDir, moonDir, rainFactor);

    float sceneL = meterLuminance(env);
    exposure = evalExposure(sceneL);
    scotopicBase = env.nightFactor * (1.0 - env.goldenFactor) * (1.0 - smoothstep(0.06, 0.30, sceneL));
    scotopicBase *= (1.0 - rainFactor * 0.4);

    float duskNightDensity = mix(0.0070, 0.0085, env.goldenFactor);
    groundFogDensity = mix(duskNightDensity, 0.0065, env.dayFactor * (1.0 - env.goldenFactor) * (1.0 - env.nightFactor));
    groundFogDensity = mix(groundFogDensity, 0.015, rainFactor);

    sunFresnel = 1.0 - fresnelWater(max(env.activeDir.y, 0.0));
    twVis = smoothstep(-0.18, 0.03, sunDir.y);

    float goldMix = smoothstep(0.0, 0.70, env.goldenFactor) * (1.0 - rainFactor);
    vec3 baseHorizon = mix(env.skyHorizon, env.ambTop, rainFactor * 0.85);
    vec3 horAnti = mix(baseHorizon, env.twAntiHor, goldMix);
    vec3 horSun = mix(baseHorizon, env.twSunHor, goldMix);
    vec3 midAnti = mix(env.skyMid, env.twAntiMid, goldMix);
    vec3 midSun = mix(env.skyMid, env.twSunMid, goldMix);

    p0 = uvec4(
        packHalf2x16(sunDir.xy),
        packHalf2x16(vec2(sunDir.z, env.activeCol.x)),
        packHalf2x16(env.activeCol.yz),
        packHalf2x16(vec2(env.dayFactor, env.goldenFactor))
    );
    p1 = uvec4(
        packHalf2x16(env.ambTop.xy),
        packHalf2x16(vec2(env.ambTop.z, env.ambBot.x)),
        packHalf2x16(env.ambBot.yz),
        packHalf2x16(vec2(env.nightFactor, env.skyHorizon.x))
    );
    p2 = uvec4(
        packHalf2x16(horAnti.xy),
        packHalf2x16(vec2(horAnti.z, horSun.x)),
        packHalf2x16(horSun.yz),
        packHalf2x16(env.skyZenith.xy)
    );
    p3 = uvec4(
        packHalf2x16(midAnti.xy),
        packHalf2x16(vec2(midAnti.z, midSun.x)),
        packHalf2x16(midSun.yz),
        packHalf2x16(vec2(env.skyZenith.z, env.skyHorizon.y))
    );
}

float getCloudShadow(vec3 worldPos, vec3 activeDir, float time, float rainFactor) {
    if (activeDir.y <= 0.01 || worldPos.y >= CLOUD_TOP) {
        return 1.0;
    }

    HP vec2 wind = vec2(time * 1.5, time * 0.6);
    HP float cloudMid = 0.5 * (CLOUD_BASE + CLOUD_TOP);
    HP float t = (cloudMid - worldPos.y) / max(activeDir.y, 0.14);
    HP vec2 hitXZ = worldPos.xz + activeDir.xz * t + wind;
    HP vec2 pCell = hitXZ * (1.0 / CLOUD_CELL);

    MP float thresh = mix(0.50, 0.05, rainFactor);
#if BGFX_SHADER_TYPE_FRAGMENT
    MP float n = texture2DLod(s_DungeonedNoise, ((pCell - vec2_splat(0.5)) * 0.35 + vec2(7.1, 3.3)) * 0.03125, 0.0).r;
#else
    MP float n = noise2D((pCell - vec2_splat(0.5)) * 0.35 + vec2(7.1, 3.3));
#endif
    MP float cover = smoothstep(thresh - 0.09, thresh + 0.09, n);

    MP float hFade = 1.0 - smoothstep(CLOUD_BASE, CLOUD_TOP, worldPos.y);
    MP float dirFade = smoothstep(0.01, 0.16, activeDir.y);
    MP float rainAtten = 1.0 - rainFactor * 0.70;
    MP float strength = 0.68 * hFade * dirFade * rainAtten;

    return 1.0 - cover * strength;
}

vec2 decodeEntityLightmap(vec4 tileLight, uvec4 p0, float rainFactor) {
    MP vec2 q0w = unpackHalf2x16(p0.w);
    MP float dayFactor = q0w.x;
    MP float goldenFactor = q0w.y;
    MP float maxSkyB = (0.12 * (1.0 - dayFactor) + 0.85 * dayFactor) * (1.0 - 0.48 * rainFactor);

    MP float twWarmth = goldenFactor * 0.28 * (1.0 - rainFactor);
    MP float warmDiff = (tileLight.r - tileLight.b * 1.05) - twWarmth * tileLight.b;
    MP float torch = clamp(warmDiff / 0.55, 0.0, 1.0);

    MP float torchBlue = torch * 0.38;
    MP float pureSkyB = max(tileLight.b - torchBlue - 0.035, 0.0);
    MP float entitySky = clamp(pureSkyB / max(maxSkyB, 0.01), 0.0, 1.0);

    return vec2(torch, entitySky);
}

vec2 decodeEntityLightmap(vec4 tileLight, uvec4 p0) {
    return decodeEntityLightmap(tileLight, p0, 0.0);
}

vec2 resolveEntityLightmap(vec4 tileIntensity, vec4 tileLight, uvec4 p0, float rainFactor) {
    float torch = clamp(tileIntensity.r, 0.0, 1.0);
    float sky = clamp(tileIntensity.g, 0.0, 1.0);

    if (tileIntensity.r <= 0.0 && tileIntensity.g <= 0.0) {
        if (tileLight.r > 0.0 || tileLight.b > 0.0) {
            return decodeEntityLightmap(tileLight, p0, rainFactor);
        }
        return vec2_splat(0.0);
    }

    if (torch > 0.01 && tileLight.r > 0.01) {
        torch = mix(torch, clamp(tileLight.r, 0.0, 1.0), 0.35);
    }
    if (sky > 0.01 && tileLight.b > 0.01) {
        sky = mix(sky, clamp(tileLight.b, 0.0, 1.0), 0.25);
    }

    return vec2(clamp(torch, 0.0, 1.0), clamp(sky, 0.0, 1.0));
}

vec2 resolveEntityLightmap(vec4 tileIntensity, vec4 tileLight, uvec4 p0) {
    return resolveEntityLightmap(tileIntensity, tileLight, p0, 0.0);
}

#endif
