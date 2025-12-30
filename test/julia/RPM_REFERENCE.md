# RPM Oscillator Reference Implementation

Power-normalized Recursive Phase Modulation oscillators.

## Canonical Implementations

### Sawtooth Mode (Linear Feedback)

```julia
function rpm_saw(omega, beta, N; alpha=0.001, k=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    curv_rms = 0.01
    phase = 0.0

    for n in 2:N
        n1, n2, n3 = n-1, max(n-2, 1), max(n-3, 1)

        # Inharmonicity: curvature-based frequency modulation
        curv = y[n1] - 2*y[n2] + y[n3]
        curv_rms += 0.001 * (curv * curv - curv_rms)
        curv_norm = curv / sqrt(max(curv_rms, 1e-6))
        phase += omega * (1.0 + k * curv_norm * curv_norm)

        # Linear feedback (2-point TPT average)
        y_avg = 0.5 * (y[n1] + y[n2])

        # Track power using single sample
        y_sq = y[n1] * y[n1]
        rms_sq += alpha * (y_sq - rms_sq)

        # RMS-normalized, scaled by 0.5, negated
        rms = sqrt(max(rms_sq, 0.01))
        u = -beta * 0.5 * (y_avg / rms)

        y[n] = sin(phase + u)
    end
    y
end
```

### Square Mode (Squared Feedback)

```julia
function rpm_sqr(omega, beta, N; alpha=0.001, k=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    curv_rms = 0.01
    phase = 0.0

    for n in 2:N
        n1, n2, n3 = n-1, max(n-2, 1), max(n-3, 1)

        # Inharmonicity: curvature-based frequency modulation
        curv = y[n1] - 2*y[n2] + y[n3]
        curv_rms += 0.001 * (curv * curv - curv_rms)
        curv_norm = curv / sqrt(max(curv_rms, 1e-6))
        phase += omega * (1.0 + k * curv_norm * curv_norm)

        # Squared feedback (2-point TPT average)
        ysq_avg = 0.5 * (y[n1]^2 + y[n2]^2)

        # Track power using ysq_avg
        rms_sq += alpha * (ysq_avg - rms_sq)

        # Power-normalized, centered around 0, negated
        u = -beta * (ysq_avg / max(rms_sq, 0.01) * 0.5 - 0.5)

        y[n] = sin(phase + u)
    end
    y
end
```

## Key Differences

| Aspect | Sawtooth | Square |
|--------|----------|--------|
| Feedback signal | `y_avg` (linear) | `ysq_avg` (squared) |
| Power tracking | `y[n-1]²` | `ysq_avg` |
| Normalization | RMS (amplitude) | Power (RMS²) |
| Scaling | `* 0.5` | `* 0.5 - 0.5` (center) |
| Harmonics | All (1, 2, 3, 4...) | Odd (1, 3, 5, 7...) |

## Parameters

| Parameter | Description | Range | Default |
|-----------|-------------|-------|---------|
| `omega` | Carrier frequency in rad/sample (`2π * f0 / fs`) | — | — |
| `beta` | Feedback strength (positive, negated in formula) | 0.5 to 3.0 | 1.5 |
| `k` | Inharmonicity coefficient | -0.1 to +0.1 | 0.0 |
| `alpha` | Power tracking smoothing coefficient | 0.0001 to 0.01 | 0.001 |

**Beta convention:** Beta is positive (e.g., `1.5`), and the formulas use `-beta`.

**Sample rate independence:** Beta does NOT need sample rate scaling. The RMS normalization compensates for different sample intervals, keeping harmonic content consistent across sample rates. Tests show <1dB difference in harmonics between 48kHz and 96kHz with identical beta.

## Morphing Between Modes

To morph between saw and square, generate both waveforms with independent feedback and crossfade outputs:

```julia
function rpm_morph(omega, beta, N; alpha=0.001, k=0.0, morph=0.0)
    y_saw = rpm_saw(omega, beta, N; alpha=alpha, k=k)
    y_sqr = rpm_sqr(omega, beta, N; alpha=alpha, k=k)
    return (1.0 - morph) .* y_saw .+ morph .* y_sqr
end
```

For sample-by-sample morphing, maintain separate state for each mode.

## Inharmonicity

The `k` parameter controls partial stretching via curvature-based frequency modulation:

- **`k > 0` (tight)**: Higher partials shift sharp (piano-like stiffness)
- **`k < 0` (loose)**: Higher partials shift flat
- **`k = 0`**: Perfect harmonic partials

Curvature (2nd derivative) scales as h² for harmonic h, so higher harmonics experience more frequency shift.

## Signal Flow

```
                              ┌─────────────────┐
                              │  Curvature      │
                              │  y[n-1] - 2y[n-2] + y[n-3]
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │  Normalize by   │
                              │  running RMS    │
                              └────────┬────────┘
                                       │
                                       ▼
┌─────────┐    ┌─────────────────────────────────────┐    ┌─────────┐
│  omega  │───▶│  phase += omega * (1 + k * curv²)   │───▶│  sin()  │───▶ y[n]
└─────────┘    └─────────────────────────────────────┘    └────┬────┘
                                                              │
                        ┌─────────────────────────────────────┘
                        │
                        ▼
             ┌──────────────────────┐
             │  Mode-specific       │
             │  feedback + normalize│
             └──────────┬───────────┘
                        │
                        └──────────────▶ phase modulation (u)

SAW MODE:                          SQR MODE:
┌────────────────────┐             ┌────────────────────┐
│ y_avg = linear TPT │             │ ysq_avg = squared  │
│ rms = sqrt(rms_sq) │             │ (use rms_sq direct)│
│ u = β * 0.5 * y/rms│             │ u = β*(ysq/rms²*0.5-0.5)│
└────────────────────┘             └────────────────────┘
```

## Example Usage

```julia
fs = 48000.0
f0 = 110.0
omega = 2π * f0 / fs
N = 48000  # 1 second

# Sawtooth
y1 = rpm_saw(omega, -1.5, N)

# Square
y2 = rpm_sqr(omega, -1.5, N)

# Sawtooth with inharmonicity
y3 = rpm_saw(omega, -1.5, N; k=0.02)

# Square with inharmonicity
y4 = rpm_sqr(omega, -1.5, N; k=0.02)
```
