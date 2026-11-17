#ifndef LIBRARIES_BRDF_GLSL
#define LIBRARIES_BRDF_GLSL

#include <libraries/common.glsl>

HP float D_GGX(MP float NoH, MP float a) {
    HP float fa = a;
    HP float fNoH = NoH;
    HP float a2 = fa * fa;
    HP float d = (fNoH * a2 - fNoH) * fNoH + 1.0;
    return a2 / max(PI * d * d, 1e-7);
}

MP float V_SmithGGXCorrelated(MP float NoV, MP float NoL, MP float a) {
    HP float fNoV = NoV;
    HP float fNoL = NoL;
    HP float fa = a;
    return 0.5 / max(mix(2.0 * fNoL * fNoV, fNoL + fNoV, fa), 1e-5);
}

MP float F_SchlickScalar(MP float u, MP float f0) {
    MP float m = clamp(1.0 - u, 0.0, 1.0);
    MP float m2 = m * m;
    return f0 + (1.0 - f0) * (m2 * m2 * m);
}

MP float Fd_OrenNayar_Terms(MP vec3 n, MP vec3 v, MP vec3 l, MP float A, MP float B) {
    MP float NoV = clamp(dot(n, v), 1e-4, 1.0);
    MP float NoL = clamp(dot(n, l), 0.0, 1.0);
    if (NoL <= 0.0) return 0.0;
    MP float s = dot(l, v) - NoL * NoV;
    MP float t = mix(1.0, max(NoL, NoV), step(0.0, s));
    return NoL * max(0.0, A + B * (s / max(t, 1e-4))) * INV_PI;
}

MP float Fd_OrenNayar(MP vec3 n, MP vec3 v, MP vec3 l, MP float roughness) {
    MP float sigma2 = roughness * roughness;
    MP float A = 1.0 - 0.5 * (sigma2 / (sigma2 + 0.33)) + 0.17 * (sigma2 / (sigma2 + 0.13));
    MP float B = 0.45 * (sigma2 / (sigma2 + 0.09));
    return Fd_OrenNayar_Terms(n, v, l, A, B);
}

MP float fresnelWater(MP float cosI) {
    MP float m = clamp(1.0 - cosI, 0.0, 1.0);
    MP float m2 = m * m;
    MP float m3 = m2 * m;
    return 0.02037 + m3 * (0.81849 + m * (-3.72252 + m * (9.27709 + m * (-10.02131 + 4.62663 * m))));
}

#endif
