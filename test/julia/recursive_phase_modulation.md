# Recursive Phase Modulation (RPM) Oscillators

A deep dive into the history, theory, and implementation of self-modulating phase oscillators.

## Historical Background

### Chowning's FM Discovery (1967)

John Chowning, a graduate student at Stanford's CCRMA, discovered frequency modulation synthesis in 1967 while experimenting with extreme vibrato. Unlike analog synthesis which required complex additive methods, FM could produce rich, evolving timbres with just two oscillators.

Stanford patented the technology but American companies (Hammond, Wurlitzer) showed no interest. In 1974, Yamaha licensed the patent and spent nearly a decade developing it into silicon, culminating in the **DX7** (1983)—the first synthesizer to sell over 100,000 units and briefly Stanford's most lucrative patent.

### Tomisawa's Feedback Extension (1978)

While Chowning's FM used separate carrier and modulator oscillators, **Norio Tomisawa** at Yamaha filed [US Patent 4,249,447](https://patents.google.com/patent/US4249447) describing a recursive variant where an oscillator modulates *itself*:

```
y[n] = sin(θ[n] + β · y[n-1])
```

This "feedback FM" (more accurately *feedback PM*) creates a continuous morphing from sine wave (β=0) toward sawtooth-like waveforms (β→1.5) using a single oscillator. It's equivalent to an infinite stack of FM modulators at the same frequency.

### The "Hunting" Phenomenon

Tomisawa's patent identifies a critical instability: when β exceeds ~1.0, "amplitude data of both positive and negative signs is alternated rapidly at each output sample point." This **hunting phenomenon** manifests as a parasitic oscillation at the Nyquist frequency, creating harsh digital artifacts.

The patent's solution: insert a **two-point averaging filter** in the feedback path:

```
filtered = 0.5 × (y[n-1] + y[n-2])
y[n] = sin(θ[n] + β · filtered)
```

This simple lowpass eliminates hunting while preserving tonal character—a technique that predates modern "TPT" (topology-preserving transform) methods by decades.

---

## Mathematical Foundation

### The Core Equation

Recursive phase modulation solves the implicit equation:

```
y = sin(θ + β·y)
```

For small β, the system is well-behaved. As β increases, the feedback creates increasingly sharp waveforms with richer harmonics.

### Stability Analysis

The equation `y = sin(θ + β·y)` can be analyzed as a fixed-point iteration. Taking the derivative:

```
dy/dy = β·cos(θ + β·y)
```

For convergence, we need `|β·cos(θ + β·y)| < 1`. When β > 1, this condition is violated whenever `cos(...)` approaches ±1, causing the iteration to diverge—the mathematical basis of the hunting phenomenon.

---

## Implementation Approaches

### 1. Naïve (Direct Form)

```julia
function rpm_naive(ω, β, N)
    y = zeros(N)
    θ = 0.0
    for n in 2:N
        θ += ω
        y[n] = sin(θ + β * y[n-1])
    end
    y
end
```

**Pros:** Simple, fast
**Cons:** Hunting artifacts when β > ~1.0

### 2. Zero-Delay Feedback (ZDF) via Newton-Raphson

Attempts to solve the implicit equation `y[n] = sin(θ + β·y[n])` directly:

```julia
function rpm_zdf(ω, β, N; iters=4)
    y = zeros(N)
    θ = 0.0
    for n in 2:N
        θ += ω
        yn = y[n-1]  # initial guess
        for _ in 1:iters
            s = sin(θ + β * yn)
            c = cos(θ + β * yn)
            yn -= (yn - s) / (1 - β * c)  # Newton step
        end
        y[n] = yn
    end
    y
end
```

**Pros:** True zero-delay feedback, theoretically "correct"
**Cons:** Newton diverges when `|β·cos(...)| ≥ 1` (denominator approaches zero or goes negative). **Catastrophically unstable** for β > 1.

### 3. ZDF via Bisection

Replace Newton with unconditionally stable bisection:

```julia
function rpm_zdf_bisect(ω, β, N; iters=16)
    y = zeros(N)
    θ = 0.0
    for n in 2:N
        θ += ω
        lo, hi = -1.0, 1.0
        for _ in 1:iters
            mid = 0.5 * (lo + hi)
            f = mid - sin(θ + β * mid)
            f > 0 ? (hi = mid) : (lo = mid)
        end
        y[n] = 0.5 * (lo + hi)
    end
    y
end
```

**Pros:** Never diverges, works at any β
**Cons:** Slow (needs ~16 iterations for good precision)

### 4. TPT (Topology-Preserving Transform)

Tomisawa's original solution—average the feedback:

```julia
function rpm_tpt(ω, β, N)
    y = zeros(N)
    θ = 0.0
    for n in 2:N
        θ += ω
        u = β * 0.5 * (y[n-1] + y[n-2])
        y[n] = sin(θ + u)
    end
    y
end
```

**Pros:** Fast, simple, stable at any β, good spectral match
**Cons:** Slight phase shift in feedback (usually inaudible)

### 5. Bunting Filter (One-Pole IIR)

A variant using exponential smoothing instead of averaging:

```c
// Pure Data external implementation
state = 0.5 * (state + pow(last_out, exponent));
out = sin(TWO_PI * phase + beta * state);
last_out = out;
```

**Pros:** Smoother transients, configurable damping, `exponent` parameter adds waveshaping
**Cons:** More damped sound, frequency-dependent delay

---

## Filter Comparison: TPT vs Bunting

| Property | TPT (2-tap FIR) | Bunting (one-pole IIR) |
|----------|-----------------|------------------------|
| Transfer function | `0.5·(1 + z⁻¹)·z⁻¹` | `0.5 / (1 - 0.5·z⁻¹)` |
| Impulse response | 2 samples | Infinite (exponential decay) |
| Memory | Finite (2 samples) | Infinite |
| Rolloff | Null at Nyquist | -6 dB/octave from DC |
| Group delay | Flat (0.5 samples) | Frequency-dependent |
| Character | Tight, responsive | Smooth, damped |

Both effectively suppress hunting, but with different sonic signatures. TPT tracks transients faster; Bunting smears them for a "softer" sound.

---

## Spectral Characteristics

As β increases from 0 to ~1.5:

| β | Waveform | Harmonic Content |
|---|----------|------------------|
| 0 | Pure sine | Fundamental only |
| 0.5 | Slightly asymmetric | Odd and even harmonics |
| 1.0 | Approaching sawtooth | Rich harmonic series |
| 1.5 | Near-sawtooth | Very bright, ~6 dB/octave rolloff |
| >1.5 | Unstable (naïve) | Hunting artifacts / noise |

---

## Squaring Variant: Odd Harmonics (Square-ish Wave)

A useful extension replaces linear feedback with squared feedback:

```
y[n] = sin(θ[n] + β · y[n-1]²)
```

### Counter-Intuitive Result

With **amplitude waveshaping**, odd-symmetric functions (like `y·|y|`) produce odd harmonics. But **phase modulation behaves differently** because the nonlinearity is wrapped inside the sin().

Empirically, **unsigned squaring (y²) with negative β** produces odd harmonics:

| Squaring Type | Formula | Result |
|---------------|---------|--------|
| Unsigned y² (negative β) | `sin(θ - |β|·y²)` | **Odd harmonics** (square-wave-like) |
| Signed y·\|y\| | `sin(θ + β·y·\|y\|)` | Mixed harmonics |

### Why Unsigned Works

With unsigned y² and negative β:
- Phase is always *pulled back* proportional to amplitude²
- Peaks (±1) get maximum phase retardation, zero crossings get none
- This specific asymmetric phase distortion produces odd harmonics

The signed version alternates phase push/pull direction with signal polarity, creating complex interactions with sin() that add even harmonics.

### Implementation (Bunting Filter)

```c
// Pd external style - one-pole IIR on unsigned y²
state = 0.5 * (state + last_out * last_out);  // unsigned y²
out = sin(TWO_PI * phase + beta * state);     // use negative beta
last_out = out;
```

### TPT Variants for Squaring

Two approaches exist for combining TPT averaging with squaring:

| Variant | Formula | Hunting Suppression |
|---------|---------|---------------------|
| **sqr→avg** | `0.5*(y[n-1]² + y[n-2]²)` | **Better** — squares first, clamps to [0,1], then averages bounded values |
| avg→sqr | `(0.5*(y[n-1] + y[n-2]))²` | Worse — averaging can preserve sign oscillations before squaring |

**Recommendation: Use sqr→avg** — it's more aggressive at killing Nyquist oscillation before it feeds back.

### DC Compensation for Phase Alignment

The average value of y² over a cycle is ~0.5 (since sin²(x) averages to 0.5). With negative β, this creates a constant phase offset that drifts the waveform. To compensate, subtract the expected DC:

```
u = β * 0.5 * (y[n-1]² + y[n-2]² - 1.0)  # DC-compensated
```

The `-1.0` removes the DC component (2 samples × 0.5 average = 1.0), centering the modulation around zero phase. This keeps waveforms aligned regardless of β.

For N-point averaging, subtract N×0.5:
- 2-point: subtract 1.0
- 3-point: subtract 1.5
- 4-point: subtract 2.0

```julia
function rpmsqr_tpt(ω, β, N)
    y = zeros(N)
    θ = 0.0
    for n in 2:N
        θ += ω
        n2 = n - 2 >= 1 ? n - 2 : 1
        u = β * 0.5 * (y[n-1]^2 + y[n2]^2 - 1.0)  # DC-compensated sqr→avg
        y[n] = sin(θ + u)
    end
    y
end
```

### Advanced DC Compensation: Adaptive vs Power Normalization

The simple analytical DC correction (subtracting 0.5 per sample) assumes y² has a fixed DC of 0.5, which is true for a pure sine wave. However, with feedback distortion—especially at higher |β| values—the actual DC of y² shifts, causing residual phase drift.

Three approaches were tested:

#### 1. Perturbation Correction (Failed)

A Taylor expansion suggests the DC of sin²(θ + βu) ≈ 0.5 + β²/4 for small β:

```julia
dc_correction = 0.5 + 0.25 * beta^2
u = beta * (ysq_avg - dc_correction)
```

**Result:** Only works for |β| < 1. At higher |β|, higher-order terms dominate and the approximation breaks down completely. Not recommended.

#### 2. Adaptive DC Tracking (Good)

Use a one-pole lowpass to track the actual DC of y² in real-time:

```julia
function rpmsqr_adaptive(ω, β, N; α=0.001)
    y = zeros(N)
    dc = 0.5  # initial estimate
    θ = 0.0
    for n in 2:N
        θ += ω
        ysq_avg = 0.5 * (y[n-1]^2 + y[max(n-2,1)]^2)
        dc += α * (ysq_avg - dc)  # lowpass tracks true DC
        u = β * (ysq_avg - dc)
        y[n] = sin(θ + u)
    end
    y
end
```

**Pros:** Self-correcting, converges to true DC regardless of β
**Cons:** Requires warmup period (~1/α samples) for DC estimate to settle

#### 3. Power Normalization (Good)

Track RMS (power) and normalize the feedback signal:

```julia
function rpmsqr_power_norm(ω, β, N; α=0.001)
    y = zeros(N)
    rms_sq = 0.5  # initial estimate of E[y²]
    θ = 0.0
    for n in 2:N
        θ += ω
        ysq_avg = 0.5 * (y[n-1]^2 + y[max(n-2,1)]^2)
        rms_sq += α * (ysq_avg - rms_sq)
        # normalize so ysq_avg/rms_sq has mean 1, then subtract 0.5
        u = β * (ysq_avg / max(rms_sq, 0.01) * 0.5 - 0.5)
        y[n] = sin(θ + u)
    end
    y
end
```

**Pros:** Self-correcting via multiplicative normalization, robust to amplitude changes
**Cons:** Division adds slight computational cost

#### Comparison

| Method | Small β | Large β | Warmup Needed | Notes |
|--------|---------|---------|---------------|-------|
| Fixed (0.5) | Good | Drifts | No | Simple but limited |
| Perturbation | Good | **Fails** | No | Don't use |
| Adaptive DC | Good | Good | Yes | Additive correction |
| Power Norm | Good | Good | Yes | Multiplicative, slightly more robust |

**Recommendation:** Use **Power Normalization** for general use—it handles both DC offset and amplitude variations gracefully. Use **Adaptive DC** if you want a simpler implementation with similar results. Avoid perturbation correction.

---

## Practical Recommendations

1. **Use TPT** for general-purpose RPM—it's Tomisawa's original solution, fast, and stable.

2. **Use Bunting** when you want softer transients or harmonic waveshaping via the exponent parameter.

3. **Avoid Newton-Raphson ZDF** for RPM—the nonlinearity defeats its convergence guarantees.

4. **Bisection ZDF** works but is slow; only use if you need true zero-delay semantics.

5. **Oversample** if you need very high β values with minimal aliasing.

---

## References

- [US4249447A - Tomisawa's Feedback PM Patent](https://patents.google.com/patent/US4249447)
- [John Chowning - Wikipedia](https://en.wikipedia.org/wiki/John_Chowning)
- [Yamaha DX7 - Wikipedia](https://en.wikipedia.org/wiki/Yamaha_DX7)
- [FM Synthesis - Stanford CCRMA](https://ccrma.stanford.edu/~jos/sasp/Frequency_Modulation_FM_Synthesis.html)
- [Discovering Digital FM: John Chowning Remembers - Yamaha](https://hub.yamaha.com/keyboards/synthesizers/discovering-digital-fm-john-chowning-remembers/)
- [Theory and Practice of Higher-Order FM Synthesis](https://www.tandfonline.com/doi/full/10.1080/09298215.2024.2312236)
