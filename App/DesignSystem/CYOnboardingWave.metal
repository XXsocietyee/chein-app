#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Onboarding fog-clear wave (Design Wave 3, B8). Ring wave radiating from `origin`.
// amp in pt, freq in 1/pt, t 0..1 progress. Same stitchable signature as the shared cyWave kit.
[[ stitchable ]] float2 cyOnboardWave(float2 pos, float2 origin, float t, float amp, float freq, float2 dir) {
    float2 d = pos - origin;
    float r = length(d);
    if (r < 0.5) { return pos; }
    float front = t * 420.0;                          // wave front radius at t (pt), sized for the 260 pt hero
    float band = exp(-pow((r - front) / 48.0, 2.0));  // gaussian ring, 48 pt wide
    float ripple = sin(r * freq - t * 24.0) * amp * band * (1.0 - t);
    float2 n = d / r;
    float2 push = n;
    if (length(dir) > 0.001) { push = normalize(mix(n, dir, 0.35)); }
    return pos + push * ripple;
}
