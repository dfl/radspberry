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
        phase += omega * (1.0 + k * abs(tanh(curv_norm)))

        # Linear feedback (2-point TPT average)
        y_avg = 0.5 * (y[n1] + y[n2])
        y_sq = y[n1] * y[n1]
        rms_sq += alpha * (y_sq - rms_sq)
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
        # tanh soft-limiting preserves spectral slope at high k
        curv = y[n1] - 2*y[n2] + y[n3]
        curv_rms += 0.001 * (curv * curv - curv_rms)
        curv_norm = curv / sqrt(max(curv_rms, 1e-6))
        phase += omega * (1.0 + k * abs(tanh(curv_norm)))

        # Squared feedback (2-point TPT average)
        ysq_avg = 0.5 * (y[n1]^2 + y[n2]^2)
        rms_sq += alpha * (ysq_avg - rms_sq)
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
| `k` | Inharmonicity coefficient | -0.5 to +0.5 | 0.0 |
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

**Why `tanh(curv_norm)`:** The `tanh` soft-limits the normalized curvature to ±1, preventing phase runaway at high k values. Without limiting, large k values cause severe spectral rolloff (up to 18 dB/oct loss for saw) by disrupting phase coherence. With `tanh`, the spectral slope stays within ±0.2 dB of the k=0 reference across the full ±0.5 range.

### F0 Drift and Compensation

Inharmonicity causes a slight f0 drift proportional to k:

```
drift ≈ f0 * k * C   where C ≈ 0.07 (saw) or 0.13 (sqr)
```

For f0=220Hz, k=-0.3: drift ≈ -4.6 Hz (~37 cents flat).

**Important:** Compensating omega directly (e.g., `omega / (1 + k*C)`) kills the inharmonicity effect due to the nonlinear feedback dynamics. Do NOT use internal compensation.

**Solution: SSB frequency shift via Hilbert transform.** Apply post-processing to shift the entire spectrum uniformly, which corrects f0 while preserving inharmonic relationships:

```julia
using DSP  # provides hilbert()

function freq_shift_ssb(x, shift_hz, fs)
    analytic = hilbert(x)  # Returns complex analytic signal
    t = (0:length(x)-1) / fs
    real.(analytic .* exp.(im * 2π * shift_hz .* t))
end

# Usage: shift up by -drift to correct
correction = -f0 * k * 0.07  # for saw (use 0.13 for square)
y_corrected = freq_shift_ssb(y, correction, fs)
```

**Real-time implementation:** Use IIR allpass filter pairs to approximate the Hilbert transform. Typical latency: 0.5-2ms depending on filter order and accuracy requirements.

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
┌─────────┐    ┌───────────────────────────────────────────────────┐    ┌─────────┐
│  omega  │───▶│  phase += omega * (1 + k * |tanh(curv_norm)|)     │───▶│  sin()  │───▶ y[n]
└─────────┘    └───────────────────────────────────────────────────┘    └────┬────┘
                                                                             │
                        ┌────────────────────────────────────────────────────┘
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
