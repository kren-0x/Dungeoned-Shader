#ifndef LIBRARIES_COLOR_SPACES_GLSL
#define LIBRARIES_COLOR_SPACES_GLSL

#include <libraries/common.glsl>

HP vec3 sRGBToLinearExact(MP vec3 c) {
    HP vec3 x = max(c, vec3_splat(0.0));
    HP vec3 lo = x * 0.0773993808;
    HP vec3 hi = pow(max((x + vec3_splat(0.055)) * 0.9478672986, vec3_splat(1e-4)), vec3_splat(2.4));
    return mix(lo, hi, step(vec3_splat(0.04045), x));
}

MP vec3 toAP1(MP vec3 srgbLinear) {
    mat3 sRGB_2_AP1 = mtxFromCols(
        vec3(0.613097, 0.070194, 0.020616),
        vec3(0.339523, 0.916354, 0.109570),
        vec3(0.047379, 0.013452, 0.869815)
    );
    return mul(sRGB_2_AP1, max(srgbLinear, vec3_splat(0.0)));
}

vec3 fromSRGB(vec3 c) {
    mat3 sRGB_2_AP1 = mtxFromCols(
        vec3(0.613097, 0.070194, 0.020616),
        vec3(0.339523, 0.916354, 0.109570),
        vec3(0.047379, 0.013452, 0.869815)
    );
    return mul(sRGB_2_AP1, sRGBToLinearExact(c));
}

MP vec3 fastFromSRGB(MP vec3 c) {
    return toAP1(sRGBToLinearExact(c));
}

MP float luminanceAP1(MP vec3 c) {
    return dot(c, vec3(0.2722287, 0.6740818, 0.0536895));
}

MP vec3 linearToSRGB(HP vec3 x) {
    HP vec3 cx = max(x, vec3_splat(0.0));
    HP vec3 lo = cx * 12.92;
    HP vec3 hi = 1.055 * pow(max(cx, vec3_splat(0.0031308)), vec3_splat(0.4166667)) - 0.055;
    return mix(lo, hi, step(vec3_splat(0.0031308), cx));
}

HP vec3 AP1ToLinearSRGB(HP vec3 ap1) {
    mat3 AP1_2_sRGB = mtxFromCols(
        vec3( 1.705051, -0.130256, -0.024003),
        vec3(-0.621792,  1.140805, -0.128969),
        vec3(-0.083259, -0.010549,  1.152972)
    );
    return mul(AP1_2_sRGB, ap1);
}

HP vec3 gamutCompressSRGB(HP vec3 lin) {
    HP float minC = min(lin.r, min(lin.g, lin.b));
    if (minC >= 0.0) {
        return lin;
    }
    HP float L = dot(lin, vec3(0.2126, 0.7152, 0.0722));
    if (L <= 0.0) {
        return vec3_splat(0.0);
    }
    HP float t = L / (L - minC);
    return max(mix(vec3_splat(L), lin, t), vec3_splat(0.0));
}

HP vec3 lottes(HP vec3 x) {
    HP vec3 safeX = max(x, vec3_splat(1e-6));
    HP vec3 z = exp2(1.25 * log2(safeX));
    HP vec3 per = z / (z + 0.415683);
    HP float peak = max(x.r, max(x.g, x.b));
    if (peak <= 1e-5) {
        return per;
    }
    HP float peakM = max(per.r, max(per.g, per.b));
    HP vec3 ratio = max(x, vec3_splat(0.0)) / peak;
    HP float pm2 = peakM * peakM;
    HP float s = pm2 * pm2 * pm2;
    HP vec3 xt = peakM * mix(ratio, vec3_splat(1.0), s * 0.22);
    HP float blend = smoothstep(0.72, 0.99, peakM) * 0.35;
    return mix(per, xt, blend);
}

MP vec3 tonemapLottes(HP vec3 linearCol) {
    HP vec3 compressed = gamutCompressSRGB(linearCol);
    HP vec3 mapped = lottes(compressed);
    return linearToSRGB(mapped);
}

MP vec3 ACEScgToDisplaySRGB(HP vec3 ap1) {
    return tonemapLottes(AP1ToLinearSRGB(ap1));
}

#endif
