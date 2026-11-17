#ifndef LIBRARIES_SURFACE_GLSL
#define LIBRARIES_SURFACE_GLSL

#include <libraries/common.glsl>
#include <libraries/luts.glsl>

#if BGFX_SHADER_TYPE_FRAGMENT
vec3 calculateFaceNormal(vec3 worldPos, vec3 camPos, float matType) {
    vec3 dpdx = dFdx(worldPos);
    vec3 dpdy = dFdy(worldPos);
    float lx2 = dot(dpdx, dpdx);
    float ly2 = dot(dpdy, dpdy);
    vec3 crs = (lx2 > 1e-18 && ly2 > 1e-18) ? cross(dpdx * inversesqrt(lx2), dpdy * inversesqrt(ly2)) : vec3_splat(0.0);
    float cLen2 = dot(crs, crs);
    if (cLen2 <= 1e-6) {
        return vec3(0.0, 1.0, 0.0);
    }
    vec3 n = crs * inversesqrt(cLen2);
    vec3 absN = abs(n);

    vec3 N;
    if (absN.y > 0.92) {
        N = vec3(0.0, camPos.y >= worldPos.y ? 1.0 : -1.0, 0.0);
    } else if (absN.x > 0.92) {
        N = vec3(camPos.x >= worldPos.x ? 1.0 : -1.0, 0.0, 0.0);
    } else if (absN.z > 0.92) {
        N = vec3(0.0, 0.0, camPos.z >= worldPos.z ? 1.0 : -1.0);
    } else {
        vec3 v = normalize(camPos - worldPos);
        N = dot(n, v) < 0.0 ? -n : n;
    }
    return N;
}
#endif

MP vec3 vertexColor(MP vec4 c) {
    MP float cLen2 = dot(c.rgb, c.rgb);
    if (cLen2 < 1e-5) {
        return vec3_splat(1.0);
    }
    MP vec3 n = c.rgb * inversesqrt(cLen2);
    MP vec3 maskvec = step(n, vec3_splat(0.5775));
    MP float mask = maskvec.x * maskvec.y * maskvec.z;

    MP float weight = step(c.a, 0.0001);
    MP float w1 = dot(c.rgb, vec3(0.19, 0.97, -0.06)) / 0.75;
    MP float w2 = dot(c.rgb, vec3(0.16, 0.97, 0.18)) / 0.88;
    MP float w = mix(w1, w2, 1.0 - weight);
    MP float maxC = max(c.r, max(c.g, c.b));
    w = max(w, maxC * 0.95);
    MP vec3 untinted = clamp(c.rgb / max(w, 0.15), vec3_splat(0.0), vec3_splat(1.0));
    return mix(mix(untinted, c.rgb, 0.35), vec3_splat(1.0), mask);
}

#if BGFX_SHADER_TYPE_FRAGMENT
MP vec3 getGridAO(MP vec3 N, MP vec3 inColor, MP float grid) {
    MP float dirShade = max(N.y, 0.0) + abs(N.z) * 0.8 + abs(N.x) * 0.6 + max(-N.y, 0.0) * 0.5;
    MP float cLen2 = dot(inColor, inColor);
    MP vec3 nCol = cLen2 > 1e-5 ? inColor * inversesqrt(cLen2) : vec3_splat(0.57735);
    MP vec3 maskvec = step(nCol, vec3_splat(0.5775));
    MP float isGrey = maskvec.x * maskvec.y * maskvec.z;
    MP float lum = mix(max(inColor.r * 0.45 + inColor.g * 0.75, max(inColor.r, max(inColor.g, inColor.b))), inColor.r, isGrey);
    MP float baseAO = clamp(lum / max(dirShade * mix(0.88, 1.0, isGrey), 0.40), 0.15, 1.0);

    MP float a = clamp(baseAO, 0.0, 1.0);
    MP float curveAO = texture2DLod(s_DungeonedLUT, vec2(a, 0.375), 0.0).g;
    MP float g = clamp(grid * 1.55, 0.0, 1.0);
    MP float gridWeight = mix(0.32, 0.10, curveAO);
    MP float shade = clamp(curveAO * mix(1.0, g * g, gridWeight), 0.16, 1.0);

    MP vec3 tint = mix(vec3(0.78, 0.84, 1.00), vec3_splat(1.0), smoothstep(0.35, 0.95, shade));
    return tint * shade;
}
#endif

#endif
