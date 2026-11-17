#ifndef INSTANCING
$input a_color0, a_position
$output v_worldPos, v_extra, v_skyPack0, v_skyPack1, v_skyPack2, v_skyPack3, v_skyPack4, v_skyPack5, v_skyPack6
#endif

#include <bgfx_shader.sh>
#include <libraries/env_pack.glsl>

#ifndef INSTANCING
uniform vec4 FogColor;
uniform vec4 FogAndDistanceControl;
uniform vec4 ViewPositionAndTime;
uniform vec4 TimeOfDay;
#endif

void main() {
#ifndef INSTANCING
    vec4 pos = vec4(a_position.xzy, 1.0);
    pos.xy = 2.0 * clamp(pos.xy, -0.5, 0.5);
    vec4 wp = mul(u_invViewProj, vec4(pos.xy, 0.5, 1.0));
    vec3 worldPos = wp.w < 0.0 ? -wp.xyz : wp.xyz;

    bool under = (FogAndDistanceControl.x == 0.0 && FogAndDistanceControl.y < 0.85 && (FogColor.b > FogColor.r || FogColor.g > FogColor.r));
    float rain = 0.0;
    if (!under) {
        rain = detectRain(FogAndDistanceControl.xyz);
    }

    float time = ViewPositionAndTime.w;
    if (time < 0.001) {
        time = TimeOfDay.x * 1200.0;
    }

    vec3 sunDir;
    vec3 moonDir;
    calculateSunParams(TimeOfDay.x, sunDir, moonDir);
    EnvLight env = getEnv(time, sunDir, moonDir, rain);

    float sceneL = meterLuminance(env);
    float exposure = evalExposure(sceneL);
    float scotopic = env.nightFactor * (1.0 - env.goldenFactor) * (1.0 - smoothstep(0.06, 0.30, sceneL));
    scotopic *= (1.0 - rain * 0.4);

    float goldMix = smoothstep(0.0, 0.70, env.goldenFactor) * (1.0 - rain);
    vec3 baseHorizon = mix(env.skyHorizon, env.ambTop, rain * 0.85);
    vec3 horAnti = mix(baseHorizon, env.twAntiHor, goldMix);
    vec3 horSun = mix(baseHorizon, env.twSunHor, goldMix);
    vec3 midAnti = mix(env.skyMid, env.twAntiMid, goldMix);
    vec3 midSun = mix(env.skyMid, env.twSunMid, goldMix);

    float sunGoldWeight = smoothstep(0.0, 0.60, env.goldenFactor);
    vec3 sunDiscSRGB = mix(vec3(1.0, 1.0, 1.0), vec3(1.0, 0.78, 0.28), sunGoldWeight);
    vec3 sunDiscCol = fromSRGB(sunDiscSRGB) * mix(4.5, 4.0, sunGoldWeight);

    vec3 sunRight = normalize(cross(sunDir, vec3(0.0, 1.0, 0.0)));
    vec3 sunUp = cross(sunRight, sunDir);
    vec3 fogAP1 = fromSRGB(FogColor.rgb);
    float sunFresnel = 1.0 - fresnelWater(max(env.activeDir.y, 0.0));

    v_worldPos = vec4(worldPos, exposure);
    v_extra = vec4(under ? 1.0 : 0.0, rain, time, scotopic);

    v_skyPack0 = uvec4(
        packHalf2x16(sunDir.xy),
        packHalf2x16(vec2(sunDir.z, env.dayFactor)),
        packHalf2x16(vec2(env.goldenFactor, env.nightFactor)),
        packHalf2x16(vec2(sunFresnel, 0.0))
    );
    v_skyPack1 = uvec4(
        packHalf2x16(horAnti.xy),
        packHalf2x16(vec2(horAnti.z, horSun.x)),
        packHalf2x16(horSun.yz),
        packHalf2x16(env.skyZenith.xy)
    );
    v_skyPack2 = uvec4(
        packHalf2x16(midAnti.xy),
        packHalf2x16(vec2(midAnti.z, midSun.x)),
        packHalf2x16(midSun.yz),
        packHalf2x16(vec2(env.skyZenith.z, env.activeCol.x))
    );
    v_skyPack3 = uvec4(
        packHalf2x16(env.activeCol.yz),
        packHalf2x16(env.sunGlow.xy),
        packHalf2x16(vec2(env.sunGlow.z, env.moonGlow.x)),
        packHalf2x16(env.moonGlow.yz)
    );
    v_skyPack4 = uvec4(
        packHalf2x16(env.cloudLit.xy),
        packHalf2x16(vec2(env.cloudLit.z, env.cloudShade.x)),
        packHalf2x16(env.cloudShade.yz),
        packHalf2x16(env.cloudRim.xy)
    );
    v_skyPack5 = uvec4(
        packHalf2x16(vec2(env.cloudRim.z, sunDiscCol.x)),
        packHalf2x16(sunDiscCol.yz),
        packHalf2x16(fogAP1.xy),
        packHalf2x16(vec2(fogAP1.z, sunRight.x))
    );
    v_skyPack6 = uvec4(
        packHalf2x16(sunRight.yz),
        packHalf2x16(sunUp.xy),
        packHalf2x16(vec2(sunUp.z, 0.0)),
        0u
    );

    gl_Position = pos;
#else
    gl_Position = vec4_splat(0.0);
#endif
}
