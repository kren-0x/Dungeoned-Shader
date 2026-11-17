#ifndef LIBRARIES_COMMON_GLSL
#define LIBRARIES_COMMON_GLSL

#define PI 3.14159265359
#define INV_PI 0.31830988618

#if BGFX_SHADER_LANGUAGE_GLSL
#define MP mediump
#define HP highp
#define LP lowp
#else
#define MP
#define HP
#define LP
#endif

HP float hash12(HP vec2 p) {
    HP vec3 p3 = fract(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

HP vec4 hash12_4(HP vec4 ix, HP vec4 iy) {
    HP vec4 px = fract(ix * 0.1031);
    HP vec4 py = fract(iy * 0.1031);
    HP vec4 d = px * (py + 33.33) + py * (px + 33.33) + px * (px + 33.33);
    px += d;
    py += d;
    return fract((px + py) * px);
}

MP float noise2D(HP vec2 p) {
    HP vec2 i = floor(p);
    MP vec2 f = p - i;
    MP vec2 u = f * f * (vec2_splat(3.0) - 2.0 * f);
    HP vec4 h = hash12_4(i.x + vec4(0.0, 1.0, 0.0, 1.0), i.y + vec4(0.0, 0.0, 1.0, 1.0));
    return mix(mix(h.x, h.y, u.x), mix(h.z, h.w, u.x), u.y);
}

MP float fastSin(MP float x) {
    MP float f = fract(x * 0.15915494 + 0.5) - 0.5;
    MP float y = 16.0 * f * (0.5 - abs(f));
    return y * (0.775 + 0.225 * abs(y));
}

MP vec2 fastSin2(MP vec2 x) {
    MP vec2 f = fract(x * 0.15915494 + 0.5) - 0.5;
    MP vec2 y = 16.0 * f * (0.5 - abs(f));
    return y * (0.775 + 0.225 * abs(y));
}

float atan_fast(float y, float x) {
    float ax = abs(x);
    float ay = abs(y);
    float a = min(ax, ay) / max(max(ax, ay), 1e-10);
    float s = a * a;
    float r = ((-0.0464964749 * s + 0.15931422) * s - 0.327622764) * s * a + a;
    if (ay > ax) r = 1.57079637 - r;
    if (x < 0.0) r = 3.14159274 - r;
    return y < 0.0 ? -r : r;
}

float acos_fast(float x) {
    float a = abs(x);
    float r = sqrt(max(1.0 - a, 0.0)) * (1.5707288 + a * (-0.2121144 + a * (0.0742610 - 0.0187293 * a)));
    return x >= 0.0 ? r : PI - r;
}

MP float hgPhase(MP float cosTheta, MP float g) {
    MP float g2 = g * g;
    MP float d = max(1.0 + g2 - 2.0 * g * cosTheta, 1e-4);
    return (1.0 - g2) * inversesqrt(d) / (4.0 * PI * d);
}

float detectRain(vec3 fogCtrl) {
    vec2 clear = vec2(0.5 + 20.0 / max(fogCtrl.z, 1.0), 1.0);
    vec2 rain = vec2(0.23, 0.70);
    vec2 factor = clamp((fogCtrl.xy - clear) / (rain - clear), 0.0, 1.0);
    float val = factor.x * factor.y;
    return val * val * (3.0 - 2.0 * val);
}

#endif
