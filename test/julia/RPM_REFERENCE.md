# RPM Oscillator Reference Implementation

Power-normalized Recursive Phase Modulation with morphable waveform and inharmonicity control.

## Algorithm

```julia
function rpm_power_norm(omega, beta, N; alpha=0.001, morph=0.0, k=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5  # initial estimate of E[y²]
    phase = 0.0
    curv_rms = 0.01  # curvature RMS for inharmonicity normalization

    for n in 2:N
        n1, n2 = n-1, max(n-2, 1)
        n3 = max(n-3, 1)

        # Inharmonicity: curvature-based frequency modulation
        curv = y[n1] - 2*y[n2] + y[n3]
        curv_rms += 0.001 * (curv * curv - curv_rms)
        curv_norm = curv / sqrt(max(curv_rms, 1e-6))
        phase += omega * (1.0 + k * curv_norm * curv_norm)

        # Compute both feedback signals
        y_avg = 0.5 * (y[n1] + y[n2])
        ysq_avg = 0.5 * (y[n1]^2 + y[n2]^2)

        # Track power (same for both modes)
        rms_sq += alpha * (ysq_avg - rms_sq)

        # Normalized feedback for each mode
        rms = sqrt(max(rms_sq, 0.01))
        u_saw = 0.5 * (y_avg / rms)                         # linear/sawtooth
        u_sqr = -(ysq_avg / max(rms_sq, 0.01) * 0.5 - 0.5)  # squared/square (sign flipped)

        # Morph between modes (0 = saw, 1 = square)
        u = beta * ((1 - morph) * u_saw + morph * u_sqr)
        y[n] = sin(phase + u)
    end
    y
end
```

## Parameters

| Parameter | Description | Range | Default |
|-----------|-------------|-------|---------|
| `omega` | Carrier frequency in rad/sample (`2π * f0 / fs`) | — | — |
| `beta` | Feedback strength (controls harmonic richness) | 0.0 – 3.0 | 1.5 |
| `morph` | Waveform morph: 0 = sawtooth (all harmonics), 1 = square (odd harmonics) | 0.0 – 1.0 | 0.0 |
| `k` | Inharmonicity coefficient | -0.03 – +0.03 | 0.0 |
| `alpha` | Power tracking smoothing coefficient | 0.0001 – 0.01 | 0.001 |

## Inharmonicity

The `k` parameter controls partial stretching:

- **`k > 0` (tight)**: Higher partials shift sharp (piano-like stiffness)
- **`k < 0` (loose)**: Higher partials shift flat (wrapped string character)
- **`k = 0`**: Perfect harmonic partials

### How it works

Curvature (2nd derivative) of the output signal scales as h² for harmonic h. By modulating the carrier frequency with normalized curvature², higher harmonics experience more frequency shift than lower ones, creating predictable inharmonicity.

The curvature is normalized by its running RMS to make `k` independent of `beta`.

### Typical values

| k | Character |
|---|-----------|
| +0.02 | Subtle piano-like sharpening |
| +0.01 | Gentle brightness |
| 0 | Harmonic |
| -0.01 | Gentle looseness |
| -0.02 | Ethnic string character |

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
              │  TPT Feedback        │
              │  y_avg, ysq_avg      │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Power Normalize     │
              │  (RMS tracking)      │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Morph: saw ↔ square │
              │  u = β * blend       │
              └──────────┬───────────┘
                         │
                         └──────────────▶ phase modulation
```

## Example Usage

```julia
fs = 48000.0
f0 = 110.0
omega = 2π * f0 / fs
N = 48000  # 1 second

# Sawtooth, harmonic
y1 = rpm_power_norm(omega, 1.5, N; morph=0.0, k=0.0)

# Square, harmonic
y2 = rpm_power_norm(omega, 1.5, N; morph=1.0, k=0.0)

# Sawtooth, tight inharmonicity
y3 = rpm_power_norm(omega, 1.5, N; morph=0.0, k=0.02)

# Square, loose inharmonicity
y4 = rpm_power_norm(omega, 1.5, N; morph=1.0, k=-0.02)
```
