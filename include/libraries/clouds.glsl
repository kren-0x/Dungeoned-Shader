#ifndef LIBRARIES_CLOUDS_GLSL
#define LIBRARIES_CLOUDS_GLSL

#include <libraries/common.glsl>
#include <libraries/color_spaces.glsl>
#include <libraries/env_pack.glsl>
#include <libraries/luts.glsl>

MP float cloudMapThresh(HP vec2 cell, MP float thresh) {
#if BGFX_SHADER_TYPE_FRAGMENT
    return step(thresh, texture2DLod(s_DungeonedNoise, (cell * 0.35 + vec2(7.1, 3.3)) * 0.03125, 0.0).r);
#else
    return step(thresh, noise2D(cell * 0.35 + vec2(7.1, 3.3)));
#endif
}

vec4 traceClouds(vec3 ro, vec3 rd, vec3 activeDir, vec3 cloudLit, vec3 cloudShade, vec3 sunGlow, float time, vec3 skyCol, vec3 fogCol, float rainFactor, bool lite, float hitDist, float borderFade, vec3 cloudRim) {
    HP vec3 wind = vec3(time * 1.5, 0.0, time * 0.6);
    HP vec3 o = ro + wind;

    HP float safeRdy = abs(rd.y) > 1e-4 ? rd.y : (rd.y >= 0.0 ? 1e-4 : -1e-4);
    HP float invRdy = 1.0 / safeRdy;
    HP float t0 = (CLOUD_BASE - o.y) * invRdy;
    HP float t1 = (CLOUD_TOP - o.y) * invRdy;
    HP float tMin = min(t0, t1);
    HP float tMax = max(t0, t1);
    HP float tMaxClamped = min(tMax, CLOUD_RANGE);
    HP float tEnter = max(tMin, 0.0);

    if (tEnter >= tMaxClamped || tEnter > CLOUD_RANGE) return vec4_splat(0.0);
    if (tEnter >= hitDist && borderFade <= 0.001) return vec4_splat(0.0);

    HP float tSlabEnd = min(tMaxClamped, tEnter + (lite ? 220.0 : 300.0));
    int stepCount = lite ? 20 : 38;

    MP float hRain = rainFactor;
    MP float thresh = mix(0.50, 0.05, hRain);
    MP vec3 hRd = rd;
    MP vec3 hActDir = activeDir;
    MP float cosV = dot(hRd, hActDir);
    MP float cV = max(cosV, 1e-4);
    MP float cV2 = cV * cV;
    MP float cV4 = cV2 * cV2;
    MP float cV8 = cV4 * cV4;
    MP float cV14 = cV8 * cV4 * cV2;
    MP float fwdMask = smoothstep(0.15, 0.95, cosV);
    MP float backScatter = fwdMask * (cV2 * sqrt(cV) * 1.15 + cV14 * 1.35);

    MP vec3 hCloudLit = cloudLit;
    MP vec3 hCloudShade = cloudShade;
    MP float dayLum = smoothstep(0.45, 1.40, luminanceAP1(hCloudLit));
    MP float dayBright = smoothstep(0.28, 0.52, hActDir.y) * dayLum * (1.0 - hRain);
    MP float sunsetCloud = smoothstep(0.15, 0.75, clamp((hCloudLit.r - hCloudLit.b * 1.35) / max(hCloudLit.r + hCloudLit.b, 0.15), 0.0, 1.0)) * (1.0 - hRain);
    MP float nightSide = smoothstep(0.20, 0.42, hActDir.y) * (1.0 - sunsetCloud) * (1.0 - hRain) * (1.0 - dayLum);

    HP vec2 screenUV = rd.xz * 1280.0 + rd.y * 720.0;
#if BGFX_SHADER_TYPE_FRAGMENT
    MP float jitter = texture2DLod(s_DungeonedNoise, screenUV * 0.0078125, 0.0).a;
#else
    MP float jitter = fract(sin(dot(screenUV, vec2(12.9898, 78.233))) * 43758.5453);
#endif

    MP vec3 whiteLit = mix(hCloudLit * 1.35, hCloudLit, hRain);
    MP vec3 blueShadow = mix(hCloudShade * 1.15, hCloudShade, hRain);
    MP vec3 sunGlow35 = sunGlow * (0.65 * (1.0 - hRain));
    MP vec3 silverTint = cloudRim;
    MP vec3 aerialTarget = skyCol;
    MP float fogStart = mix(mix(320.0, 140.0, sunsetCloud), 45.0, hRain);
    MP float fogRateLog2 = mix(mix(0.0045, 0.0052, sunsetCloud), 0.0125, hRain) * 1.44269504;

    HP vec2 pStart = o.xz + rd.xz * tEnter;
    HP vec2 cell = floor(pStart * (1.0 / CLOUD_CELL));
    HP float stepX = rd.x >= 0.0 ? 1.0 : -1.0;
    HP float stepZ = rd.z >= 0.0 ? 1.0 : -1.0;
    HP float tDeltaX = abs(rd.x) > 1e-6 ? CLOUD_CELL / abs(rd.x) : 1e9;
    HP float tDeltaZ = abs(rd.z) > 1e-6 ? CLOUD_CELL / abs(rd.z) : 1e9;

    HP float nextX = (cell.x + (rd.x >= 0.0 ? 1.0 : 0.0)) * CLOUD_CELL;
    HP float nextZ = (cell.y + (rd.z >= 0.0 ? 1.0 : 0.0)) * CLOUD_CELL;
    HP float tMaxX = abs(rd.x) > 1e-6 ? max((nextX - o.x) / rd.x, tEnter) : 1e9;
    HP float tMaxZ = abs(rd.z) > 1e-6 ? max((nextZ - o.z) / rd.z, tEnter) : 1e9;

    MP vec3 accum = vec3_splat(0.0);
    MP float trans = 1.0;
    MP float bevel = 0.22;
    HP float hitT = 1e6;
    HP float tCurr = tEnter;
    int budget = lite ? 16 : 30;
    HP float subMaxLen = lite ? 1.8 : 1.35;
    MP float invSubMaxLen = 1.0 / subMaxLen;
    MP float invCell = 1.0 / CLOUD_CELL;
    MP float invHeight = 1.0 / (CLOUD_TOP - CLOUD_BASE);
    MP vec2 rimShift = hRd.xz * (4.2 * invCell);

    MP float cW = 0.0;
    MP float cE = 0.0;
    MP float cS = 0.0;
    MP float cN = 0.0;
    MP float cSW = 0.0;
    MP float cSE = 0.0;
    MP float cNW = 0.0;
    MP float cNE = 0.0;
    int cacheMove = 0;

    for (int i = 0; i < 38; i++) {
        if (i >= stepCount || budget <= 0 || trans < 0.02) break;
        if (tCurr >= tSlabEnd) break;
        if (tCurr >= hitDist && borderFade <= 0.001) break;

        HP float tNext = min(min(tMaxX, tMaxZ), tSlabEnd);
        HP float segEnd = borderFade <= 0.001 ? min(tNext, hitDist) : tNext;
        HP float dt = max(segEnd - tCurr, 0.0);

        MP float hasCloud = 0.0;
        if (cacheMove == 1) {
            hasCloud = cE;
        } else if (cacheMove == -1) {
            hasCloud = cW;
        } else if (cacheMove == 2) {
            hasCloud = cN;
        } else if (cacheMove == -2) {
            hasCloud = cS;
        } else {
            hasCloud = cloudMapThresh(cell, thresh);
        }

        if (dt > 1e-4 && hasCloud > 0.5) {
            if (cacheMove == 1) {
                cW = 1.0;
                cSW = cS;
                cNW = cN;
                cS = cSE;
                cN = cNE;
                cE = cloudMapThresh(cell + vec2(1.0, 0.0), thresh);
                cSE = cloudMapThresh(cell + vec2(1.0, -1.0), thresh);
                cNE = cloudMapThresh(cell + vec2(1.0, 1.0), thresh);
            } else if (cacheMove == -1) {
                cE = 1.0;
                cSE = cS;
                cNE = cN;
                cS = cSW;
                cN = cNW;
                cW = cloudMapThresh(cell + vec2(-1.0, 0.0), thresh);
                cSW = cloudMapThresh(cell + vec2(-1.0, -1.0), thresh);
                cNW = cloudMapThresh(cell + vec2(-1.0, 1.0), thresh);
            } else if (cacheMove == 2) {
                cS = 1.0;
                cSW = cW;
                cSE = cE;
                cW = cNW;
                cE = cNE;
                cN = cloudMapThresh(cell + vec2(0.0, 1.0), thresh);
                cNW = cloudMapThresh(cell + vec2(-1.0, 1.0), thresh);
                cNE = cloudMapThresh(cell + vec2(1.0, 1.0), thresh);
            } else if (cacheMove == -2) {
                cN = 1.0;
                cNW = cW;
                cNE = cE;
                cW = cSW;
                cE = cSE;
                cS = cloudMapThresh(cell + vec2(0.0, -1.0), thresh);
                cSW = cloudMapThresh(cell + vec2(-1.0, -1.0), thresh);
                cSE = cloudMapThresh(cell + vec2(1.0, -1.0), thresh);
            } else {
                cW = cloudMapThresh(cell + vec2(-1.0, 0.0), thresh);
                cE = cloudMapThresh(cell + vec2(1.0, 0.0), thresh);
                cS = cloudMapThresh(cell + vec2(0.0, -1.0), thresh);
                cN = cloudMapThresh(cell + vec2(0.0, 1.0), thresh);
                cSW = cloudMapThresh(cell + vec2(-1.0, -1.0), thresh);
                cSE = cloudMapThresh(cell + vec2(1.0, -1.0), thresh);
                cNW = cloudMapThresh(cell + vec2(-1.0, 1.0), thresh);
                cNE = cloudMapThresh(cell + vec2(1.0, 1.0), thresh);
            }

            MP float fwdX = stepX > 0.0 ? cE : cW;
            MP float fwdZ = stepZ > 0.0 ? cN : cS;

            bool allCard = (cW > 0.5 && cE > 0.5 && cS > 0.5 && cN > 0.5);
            bool allDiag = (cSW > 0.5 && cSE > 0.5 && cNW > 0.5 && cNE > 0.5);
            bool allSolid = allCard && allDiag;

            MP float tMid = 0.5 * (tCurr + segEnd);
            MP float skyFade = exp2(-max(tMid - fogStart, 0.0) * fogRateLog2);
            HP vec3 p0 = o + rd * tCurr;
            MP vec2 f0 = clamp(p0.xz * invCell - cell, 0.0, 1.0);
            MP float y0 = clamp((p0.y - CLOUD_BASE) * invHeight, 0.0, 1.0);
            MP float y1 = clamp((p0.y + rd.y * dt - CLOUD_BASE) * invHeight, 0.0, 1.0);

            if (allSolid && min(y0, y1) >= bevel && max(y0, y1) <= 1.0 - bevel) {
                hitT = min(hitT, tCurr);
                budget--;
                MP float a = 1.0 - exp2(-dt * (1.25 * 1.44269504));
                MP float yMid = 0.5 * (y0 + y1);
                MP float topSun = clamp(hActDir.y, 0.0, 1.0);
                MP float sunPen = smoothstep(0.20, 0.85, yMid) * topSun;
                MP float litFactor = clamp(sunPen * 0.85 + 0.15 * yMid, 0.0, 1.0);
                MP vec3 c = mix(blueShadow * (0.65 + 0.35 * yMid), whiteLit, litFactor);
                c += sunGlow35 * sunPen;
                if (hRain > 0.001) {
                    MP vec3 rainCloudCol = mix(hCloudShade, hCloudLit, 0.35 + 0.65 * yMid);
                    c = mix(c, rainCloudCol, hRain);
                }
                MP vec3 stepScat = mix(aerialTarget, c, skyFade);
                accum += trans * a * stepScat;
                trans *= 1.0 - a;
            } else {
                int subSteps = int(clamp(ceil(dt * invSubMaxLen), 1.0, lite ? 6.0 : 9.0));
                subSteps = min(subSteps, budget);
                HP float subDt = dt / float(subSteps);
                MP vec2 df = hRd.xz * (subDt * invCell);
                MP float dy = hRd.y * (subDt * invHeight);
                MP float negSubExt = -subDt * (1.25 * 1.44269504);

                MP float defaultNy = o.y > CLOUD_TOP ? 1.0 : (o.y < CLOUD_BASE ? -1.0 : clamp((y0 - 0.5) * 3.0, -1.0, 1.0));
                MP vec3 lastN = vec3(0.0, defaultNy, 0.0);

                for (int s = 0; s < 9; s++) {
                    if (s >= subSteps) break;
                    budget--;

                    MP float sFrac = float(s) + jitter;
                    MP vec2 f = f0 + df * sFrac;
                    MP float yNorm = y0 + dy * sFrac;

                    MP float dW = cW > 0.5 ? 10.0 : f.x;
                    MP float dE = cE > 0.5 ? 10.0 : 1.0 - f.x;
                    MP float dS = cS > 0.5 ? 10.0 : f.y;
                    MP float dN = cN > 0.5 ? 10.0 : 1.0 - f.y;

                    MP float dCard = 10.0;
                    if (!allCard) {
                        MP float ox = max(bevel - min(dW, dE), 0.0);
                        MP float oz = max(bevel - min(dS, dN), 0.0);
                        dCard = bevel - sqrt(ox * ox + oz * oz);
                    }

                    MP float dAirXZ = dCard;
                    MP float dBot = yNorm;
                    MP float dTop = 1.0 - yNorm;
                    MP float dAirY = min(dBot, dTop);

                    MP float ox3 = max(bevel - dAirXZ, 0.0);
                    MP float oy3 = max(bevel - dAirY, 0.0);
                    MP float roundDist = bevel - sqrt(ox3 * ox3 + oy3 * oy3);
                    MP float density = smoothstep(0.0, bevel, roundDist);

                    if (density > 0.002) {
                        MP float a = 1.0 - exp2(density * negSubExt);
                        if (a > 0.001) {
                            HP float tSample = tCurr + subDt * sFrac;
                            hitT = min(hitT, tSample);

                            MP vec2 cardPush = vec2(
                                max(bevel - dE, 0.0) - max(bevel - dW, 0.0),
                                max(bevel - dN, 0.0) - max(bevel - dS, 0.0)
                            );
                            MP float nY = max(bevel - dTop, 0.0) - max(bevel - dBot, 0.0);
                            MP vec3 nVec = vec3(cardPush.x, nY, cardPush.y);
                            MP float nLenSq = dot(nVec, nVec);
                            if (nLenSq > 1e-5) {
                                lastN = nVec * inversesqrt(nLenSq);
                            }
                            MP vec3 N = lastN;

                            MP float NoL = dot(N, hActDir);
                            MP float NoV = abs(dot(N, hRd));

                            MP float sunPen = smoothstep(0.20, 0.85, yNorm) * clamp(hActDir.y, 0.0, 1.0);
                            MP float directSun = max(clamp(NoL, 0.0, 1.0), sunPen * 0.50);
                            MP float effSun = directSun;
                            if (dayBright > 0.001) {
                                MP float dayWrap = clamp((NoL + 0.55) / 1.55, 0.0, 1.0);
                                MP float daySideLift = (1.0 - abs(N.y)) * 0.30;
                                effSun = mix(directSun, max(directSun, max(dayWrap * 0.65, daySideLift)), dayBright);
                            }
                            if (nightSide > 0.001) {
                                MP float sideLift = (1.0 - abs(N.y)) * 0.28;
                                effSun = max(effSun, sideLift * nightSide);
                            }
                            MP float litFactor = clamp(effSun * 0.85 + 0.15 * yNorm * effSun, 0.0, 1.0);

                            MP vec3 c = mix(blueShadow * (0.65 + 0.35 * yNorm), whiteLit, litFactor);
                            c += sunGlow35 * directSun;

                            if (hRain < 0.99) {
                                MP float shell = 1.0 - smoothstep(0.0, bevel * 1.40, roundDist);
                                if (shell > 0.01) {
                                    MP float outAir = 0.0;
                                    if (NoL > -0.22 || fwdMask > 0.01) {
                                        HP float qY = p0.y + rd.y * (subDt * sFrac + 4.2);
                                        MP float qOutY = (qY >= CLOUD_TOP - 0.4 || (o.y > CLOUD_TOP && qY <= CLOUD_BASE + 0.2)) ? 1.0 : 0.0;
                                        MP vec2 fq = f + rimShift;
                                        bool qX = (fq.x >= 1.0) || (fq.x < 0.0);
                                        bool qZ = (fq.y >= 1.0) || (fq.y < 0.0);
                                        MP float qOcc = qX ? (qZ ? (fwdX * fwdZ) : fwdX) : (qZ ? fwdZ : 1.0);
                                        MP float qOutXZ = qOcc < 0.5 ? 1.0 : 0.0;
                                        outAir = max(qOutY, qOutXZ);
                                    }
                                    MP float edgeSide = max(1.0 - smoothstep(0.0, bevel * 0.90, dAirXZ), 1.0 - smoothstep(0.0, bevel * 0.90, dTop));
                                    MP float grazing = 1.0 - smoothstep(0.15, 0.68, NoV);
                                    MP float rimMask = shell * clamp(max(outAir, edgeSide * grazing), 0.0, 1.0);

                                    MP float sunHitRim = smoothstep(0.05, 0.75, NoL) * mix(0.45, 0.22, dayBright);
                                    MP float dirAllow = smoothstep(-0.22, 0.50, NoL);
                                    MP float rimStrength = (sunHitRim + backScatter * dirAllow) * rimMask * (1.0 - hRain);
                                    c += silverTint * rimStrength;
                                }
                            }

                            if (hRain > 0.001) {
                                MP vec3 rainCloudCol = mix(hCloudShade, hCloudLit, 0.35 + 0.65 * yNorm);
                                c = mix(c, rainCloudCol, hRain);
                            }

                            MP vec3 stepScat = mix(aerialTarget, c, skyFade);
                            accum += trans * a * stepScat;
                            trans *= 1.0 - a;
                            if (trans < 0.02) break;
                        }
                    }
                }
            }
            cacheMove = tMaxX < tMaxZ ? (stepX > 0.0 ? 1 : -1) : (stepZ > 0.0 ? 2 : -2);
        } else {
            cacheMove = 0;
        }

        if (tMaxX < tMaxZ) {
            tCurr = tMaxX;
            tMaxX += tDeltaX;
            cell.x += stepX;
        } else {
            tCurr = tMaxZ;
            tMaxZ += tDeltaZ;
            cell.y += stepZ;
        }
    }

    MP float alpha = 1.0 - trans;
    if (alpha < 0.005) return vec4_splat(0.0);

    MP vec3 cloudCol = accum / max(alpha, 1e-4);

    if (hitT < 1e5) {
        MP float horEnd = mix(0.025, 0.14, sunsetCloud);
        MP float horizonFade = smoothstep(0.002, horEnd, abs(hRd.y));
        if (rd.y < -0.05) horizonFade = 1.0;
        MP float rainHorFade = smoothstep(0.002, 0.22, abs(hRd.y));
        MP float fade = mix(horizonFade, rainHorFade, hRain);
        MP float distFar = smoothstep(40.0, 180.0, hitT);
        fade = mix(1.0, fade, distFar);
        cloudCol = mix(aerialTarget, cloudCol, fade);
        cloudCol = mix(cloudCol, aerialTarget, smoothstep(CLOUD_RANGE * 0.65, CLOUD_RANGE * 0.96, hitT));
        alpha *= mix(1.0, rainHorFade, hRain);
        alpha *= 1.0 - smoothstep(CLOUD_RANGE * 0.90, CLOUD_RANGE, hitT);
    }

    if (hitT >= hitDist && hitDist < CLOUD_RANGE) {
        alpha *= borderFade;
    }

    return vec4(cloudCol, alpha);
}

vec4 traceClouds(vec3 ro, vec3 rd, vec3 activeDir, vec3 cloudLit, vec3 cloudShade, vec3 sunGlow, float time, vec3 skyCol, vec3 fogCol, float rainFactor, bool lite, float hitDist, float borderFade) {
    return traceClouds(ro, rd, activeDir, cloudLit, cloudShade, sunGlow, time, skyCol, fogCol, rainFactor, lite, hitDist, borderFade, cloudLit * 1.10 + sunGlow * 0.90);
}

vec4 traceClouds(vec3 ro, vec3 rd, vec3 activeDir, vec3 cloudLit, vec3 cloudShade, vec3 sunGlow, float time, vec3 skyCol, vec3 fogCol, float rainFactor, bool lite, float maxDist) {
    return traceClouds(ro, rd, activeDir, cloudLit, cloudShade, sunGlow, time, skyCol, fogCol, rainFactor, lite, maxDist, 0.0);
}

vec4 traceClouds(vec3 ro, vec3 rd, vec3 activeDir, vec3 cloudLit, vec3 cloudShade, vec3 sunGlow, float time, vec3 skyCol, vec3 fogCol, float rainFactor, bool lite) {
    return traceClouds(ro, rd, activeDir, cloudLit, cloudShade, sunGlow, time, skyCol, fogCol, rainFactor, lite, CLOUD_RANGE);
}

vec4 traceClouds(vec3 ro, vec3 rd, vec3 activeDir, vec3 cloudLit, vec3 cloudShade, vec3 sunGlow, float time, vec3 skyCol, vec3 fogCol, float rainFactor) {
    return traceClouds(ro, rd, activeDir, cloudLit, cloudShade, sunGlow, time, skyCol, fogCol, rainFactor, false, CLOUD_RANGE);
}

vec4 traceClouds(vec3 ro, vec3 rd, vec3 activeDir, vec3 cloudLit, vec3 cloudShade, vec3 sunGlow, float time, vec3 skyCol, float rainFactor) {
    return traceClouds(ro, rd, activeDir, cloudLit, cloudShade, sunGlow, time, skyCol, vec3(0.7, 0.8, 0.9), rainFactor, false, CLOUD_RANGE);
}

vec4 traceClouds(vec3 ro, vec3 rd, vec3 activeDir, vec3 cloudLit, vec3 cloudShade, vec3 sunGlow, float time, vec3 skyCol) {
    return traceClouds(ro, rd, activeDir, cloudLit, cloudShade, sunGlow, time, skyCol, vec3(0.7, 0.8, 0.9), 0.0, false, CLOUD_RANGE);
}

#endif
