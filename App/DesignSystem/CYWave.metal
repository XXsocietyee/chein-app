#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Ring wave radiating from a touch point (wave 3 B2). Stitchable signature per design-wave3.md 3.1.
// origin in pt, t 0..1 (progress), amp in pt, freq in 1/pt, dir = normalised touch-to-centre.
// The wave front travels 520 pt (a Today-card diagonal plus the 60 pt band), so the ring crosses the
// whole card within the 800 ms run instead of leaving it after 45 % of the time.
[[ stitchable ]] float2 cyWave(float2 pos, float2 origin, float t, float amp, float freq, float2 dir) {
    float2 d = pos - origin;
    float r = length(d);
    float front = t * 520.0;
    float band = exp(-pow((r - front) / 60.0, 2.0));
    float ripple = sin(r * freq - t * 24.0) * amp * band * (1.0 - t);
    float2 n = r > 0.5 ? d / r : float2(0.0);
    float2 mixed = mix(n, dir, 0.35);
    float m = length(mixed);
    float2 push = m > 0.001 ? mixed / m : float2(0.0);
    return pos + push * ripple;
}
