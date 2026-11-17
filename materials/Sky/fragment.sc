#ifndef INSTANCING
$input v_worldPos, v_extra, v_skyPack0, v_skyPack1, v_skyPack2, v_skyPack3, v_skyPack4, v_skyPack5, v_skyPack6
#endif

#include <bgfx_shader.sh>
#define NO_LEGACY_SHADING
#include <libraries/sky.glsl>

#ifndef INSTANCING
uniform vec4 TimeOfDay;
uniform vec4 ViewPositionAndTime;
uniform vec4 CameraPosition;
#endif

void main() {
#ifndef INSTANCING
    vec3 worldPos = v_worldPos.xyz;
    MP float exposure = v_worldPos.w;
    float isUnderwater = v_extra.x;
    float rainFactor = v_extra.y;
    float time = ViewPositionAndTime.w;
    if (time < 0.001) {
        time = v_extra.z;
    }
    MP float scotopic = v_extra.w;
    float cloudTime = TimeOfDay.x * 1200.0;

    MP vec2 p0x = unpackHalf2x16(v_skyPack0.x);
    MP vec2 p0y = unpackHalf2x16(v_skyPack0.y);
    MP vec2 p0z = unpackHalf2x16(v_skyPack0.z);
    MP vec2 p0w = unpackHalf2x16(v_skyPack0.w);
    MP vec3 sunDir = vec3(p0x, p0y.x);
    MP float dayFactor = p0y.y;
    MP float goldenFactor = p0z.x;
    MP float nightFactor = p0z.y;
    MP float sunFresnel = p0w.x;

    MP vec2 p1x = unpackHalf2x16(v_skyPack1.x);
    MP vec2 p1y = unpackHalf2x16(v_skyPack1.y);
    MP vec2 p1z = unpackHalf2x16(v_skyPack1.z);
    MP vec2 p1w = unpackHalf2x16(v_skyPack1.w);
    MP vec3 horAnti = vec3(p1x, p1y.x);
    MP vec3 horSun = vec3(p1y.y, p1z);

    MP vec2 p2x = unpackHalf2x16(v_skyPack2.x);
    MP vec2 p2y = unpackHalf2x16(v_skyPack2.y);
    MP vec2 p2z = unpackHalf2x16(v_skyPack2.z);
    MP vec2 p2w = unpackHalf2x16(v_skyPack2.w);
    MP vec3 midAnti = vec3(p2x, p2y.x);
    MP vec3 midSun = vec3(p2y.y, p2z);
    MP vec3 skyZenith = vec3(p1w, p2w.x);

    MP vec2 p3x = unpackHalf2x16(v_skyPack3.x);
    MP vec2 p3y = unpackHalf2x16(v_skyPack3.y);
    MP vec2 p3z = unpackHalf2x16(v_skyPack3.z);
    MP vec2 p3w = unpackHalf2x16(v_skyPack3.w);
    MP vec3 activeCol = vec3(p2w.y, p3x);
    MP vec3 sunGlow = vec3(p3y, p3z.x);
    MP vec3 moonGlow = vec3(p3z.y, p3w);

    MP vec2 p4x = unpackHalf2x16(v_skyPack4.x);
    MP vec2 p4y = unpackHalf2x16(v_skyPack4.y);
    MP vec2 p4z = unpackHalf2x16(v_skyPack4.z);
    MP vec2 p4w = unpackHalf2x16(v_skyPack4.w);
    MP vec3 cloudLit = vec3(p4x, p4y.x);
    MP vec3 cloudShade = vec3(p4y.y, p4z);

    MP vec2 p5x = unpackHalf2x16(v_skyPack5.x);
    MP vec2 p5y = unpackHalf2x16(v_skyPack5.y);
    MP vec2 p5z = unpackHalf2x16(v_skyPack5.z);
    MP vec2 p5w = unpackHalf2x16(v_skyPack5.w);
    MP vec3 cloudRim = vec3(p4w, p5x.x);
    MP vec3 sunDiscCol = vec3(p5x.y, p5y);
    MP vec3 fogAP1 = vec3(p5z, p5w.x);

    MP vec2 p6x = unpackHalf2x16(v_skyPack6.x);
    MP vec2 p6y = unpackHalf2x16(v_skyPack6.y);
    MP vec2 p6z = unpackHalf2x16(v_skyPack6.z);
    MP vec3 sunRight = vec3(p5w.y, p6x);
    MP vec3 sunUp = vec3(p6y, p6z.x);

    gl_FragColor = evaluateSkyPrecomputed(
        worldPos,
        CameraPosition.xyz,
        time,
        cloudTime,
        isUnderwater,
        rainFactor,
        exposure,
        scotopic,
        sunDir,
        dayFactor,
        goldenFactor,
        nightFactor,
        horAnti,
        horSun,
        midAnti,
        midSun,
        skyZenith,
        sunGlow,
        moonGlow,
        activeCol,
        cloudLit,
        cloudShade,
        cloudRim,
        sunDiscCol,
        sunRight,
        sunUp,
        fogAP1,
        sunFresnel
    );
#else
    gl_FragColor = vec4_splat(0.0);
#endif
}
