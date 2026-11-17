#ifndef LIBRARIES_WATER_GLSL
#define LIBRARIES_WATER_GLSL

#include <libraries/common.glsl>

HP vec2 snapWater(HP vec2 p) {
    return (floor(p * 16.0) + 0.5) * 0.0625;
}

MP vec2 waterGrad(HP vec2 p, MP float dist, HP float time) {
    if (dist >= 100.0) {
        return vec2_splat(0.0);
    }
    p = snapWater(p);
    HP float t = time * 0.75;
    MP vec2 d1 = vec2(0.7071, 0.7071);
    MP vec2 d2 = vec2(-0.6, 0.8);
    HP vec2 phase = vec2(
        dot(p, vec2(0.7071, 0.7071)) * 0.75 + t * 0.90,
        dot(p, vec2(-0.6, 0.8)) * 1.10 - t * 0.75
    );
    MP vec2 s = fastSin2(fract(phase * 0.15915494) * 6.2831853);
    MP vec2 g = d1 * (0.012 * s.x) + d2 * (0.008 * s.y);
    return g * (1.0 - smoothstep(35.0, 100.0, dist));
}

MP vec3 waterSurfaceNormal(HP vec3 q, MP vec3 nOut, MP float dist, HP float time) {
    if (dist >= 100.0) {
        return nOut;
    }
    if (nOut.y > 0.5) {
        MP vec2 g = waterGrad(q.xz, dist, time);
        MP vec3 wn = vec3(-g.x, 1.0, -g.y);
        return wn * inversesqrt(dot(wn, wn));
    }
    bool xFace = abs(nOut.x) > 0.5;
    HP vec2 uv = xFace ? vec2(q.z, q.y) : vec2(q.x, q.y);
    uv += xFace ? 13.0 * nOut.x : 29.0 * nOut.z;
    MP vec2 g = waterGrad(uv, dist, time) * 0.5;
    MP vec3 t1 = xFace ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    MP vec3 wn = nOut - g.x * t1 - g.y * vec3(0.0, 1.0, 0.0);
    return wn * inversesqrt(dot(wn, wn));
}

#endif
