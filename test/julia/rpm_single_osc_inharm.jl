using DSP, FFTW, Plots
gr()

fs      = 48000.0
f0      = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 110.0
beta    = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 1.5
omega   = 2π * f0 / fs
N       = 16384
discard = 4096

sqr(y) = y * y

# =====================================================
# SINGLE OSCILLATOR INHARMONICITY
# =====================================================
# The challenge: sin(phase) produces harmonics at exact
# integer multiples. We need to create inharmonicity
# while keeping a single oscillator.
#
# Approach: Modulate the CARRIER FREQUENCY based on
# the instantaneous frequency content of the signal.
# Higher harmonics → different frequency modulation
# =====================================================

# -----------------------------
# Reference: Standard RPM
# -----------------------------
function rpm_reference(omega, beta, N; alpha=0.001)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2 = n-1, max(n-2, 1)
        y_tpt = 0.5 * (y[n1] + y[n2])
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))
        u = beta * y_tpt / rms
        y[n] = sin(phase + u)
    end
    y
end

# -----------------------------
# Method 1: Frequency modulation by curvature
#
# Idea: Higher harmonics have more "curvature" (2nd derivative).
# Use curvature to modulate carrier frequency.
# B > 0: more curvature → higher freq (tight)
# B < 0: more curvature → lower freq (loose)
# -----------------------------
function rpm_curvature_fm(omega, beta, N; alpha=0.001, B=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    curvature_smooth = 0.0

    for n in 4:N
        n1, n2, n3 = n-1, n-2, n-3

        # Estimate curvature (second derivative)
        curvature = abs(y[n1] - 2*y[n2] + y[n3])
        curvature_smooth += 0.01 * (curvature - curvature_smooth)

        # Frequency modulation based on curvature
        # Curvature is roughly proportional to harmonic number squared
        freq_mod = 1.0 + B * curvature_smooth
        phase += omega * freq_mod

        # Standard RPM feedback
        y_tpt = 0.5 * (y[n1] + y[n2])
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))
        u = beta * y_tpt / rms

        y[n] = sin(phase + u)
    end
    y
end

# -----------------------------
# Method 2: Phase warping
#
# Apply a nonlinear transformation to the phase that
# stretches/compresses based on harmonic content.
# Use allpass-filtered phase difference.
# -----------------------------
function rpm_phase_warp(omega, beta, N; alpha=0.001, warp=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    phase_filtered = 0.0
    ap_coef = clamp(warp, -0.9, 0.9)
    ap_z1 = 0.0

    for n in 2:N
        n1, n2 = n-1, max(n-2, 1)

        # Advance base phase
        phase += omega

        # Apply allpass to phase increment based on feedback
        # This creates frequency-dependent phase warping
        y_tpt = 0.5 * (y[n1] + y[n2])
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))

        # Allpass on feedback creates phase shift
        x = y[n1]
        ap_out = ap_coef * x + ap_z1
        ap_z1 = x - ap_coef * ap_out

        # Difference creates freq-dependent correction
        phase_correction = warp * (ap_out - x) * 0.1

        u = beta * y_tpt / rms
        y[n] = sin(phase + phase_correction + u)
    end
    y
end

# -----------------------------
# Method 3: Instantaneous frequency tracking + stretch
#
# Track the instantaneous frequency from phase derivative,
# then apply a stretching factor based on detected frequency.
# -----------------------------
function rpm_if_stretch(omega, beta, N; alpha=0.001, B=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    inst_freq = omega  # Estimated instantaneous frequency
    last_zero_cross = 1
    period_estimate = 2π / omega

    for n in 3:N
        n1, n2 = n-1, n-2

        # Detect zero crossings for period estimation
        if y[n1] >= 0 && y[n2] < 0
            period = n - last_zero_cross
            last_zero_cross = n
            if period > 2
                inst_freq = 0.9 * inst_freq + 0.1 * (2π / period)
            end
        end

        # Stretch factor based on instantaneous frequency
        # Higher freq = more stretch when B > 0
        freq_ratio = inst_freq / omega
        stretch = 1.0 + B * (freq_ratio - 1.0) * freq_ratio

        phase += omega * stretch

        # Standard feedback
        y_tpt = 0.5 * (y[n1] + y[n2])
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))
        u = beta * y_tpt / rms

        y[n] = sin(phase + u)
    end
    y
end

# -----------------------------
# Method 4: Allpass cascade on modulation with phase feedback
#
# Use allpass to create frequency-dependent delay on feedback,
# then use difference to modulate phase rate
# -----------------------------
function rpm_allpass_freq_mod(omega, beta, N; alpha=0.001, B=0.0, stages=8)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0

    # Cascade of allpass filters
    a = 0.5  # Fixed allpass coefficient
    ap_states = zeros(Float64, stages)

    for n in 2:N
        n1, n2 = n-1, max(n-2, 1)

        # Pass feedback through allpass cascade
        sig = y[n1]
        for s in 1:stages
            x = sig
            sig = a * x + ap_states[s]
            ap_states[s] = x - a * sig
        end

        # Difference between original and dispersed
        # This is larger for higher frequencies
        dispersion = sig - y[n1]

        # Use dispersion to modulate frequency
        freq_mod = 1.0 + B * dispersion
        phase += omega * freq_mod

        # Feedback
        y_tpt = 0.5 * (y[n1] + y[n2])
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))
        u = beta * y_tpt / rms

        y[n] = sin(phase + u)
    end
    y
end

# -----------------------------
# Method 5: Energy-based frequency stretch
#
# Track energy at different "bands" (approximated by
# derivatives) and use to stretch frequency
# -----------------------------
function rpm_energy_stretch(omega, beta, N; alpha=0.001, B=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    energy_lo = 0.0  # Low freq energy (smoothed signal)
    energy_hi = 0.0  # High freq energy (derivative energy)
    lp_state = 0.0
    lp_coef = 0.1    # Lowpass for "low band"

    for n in 3:N
        n1, n2 = n-1, n-2

        # Split into low and high frequency content
        lp_state += lp_coef * (y[n1] - lp_state)
        hi_freq = y[n1] - lp_state

        # Track energy in each band
        energy_lo += 0.01 * (sqr(lp_state) - energy_lo)
        energy_hi += 0.01 * (sqr(hi_freq) - energy_hi)

        # Ratio of high to low determines stretch
        total_energy = energy_lo + energy_hi + 0.001
        hi_ratio = energy_hi / total_energy

        # Stretch frequency based on high freq content
        stretch = 1.0 + B * hi_ratio * 2.0
        phase += omega * stretch

        # Standard feedback
        y_tpt = 0.5 * (y[n1] + y[n2])
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))
        u = beta * y_tpt / rms

        y[n] = sin(phase + u)
    end
    y
end

# -----------------------------
# Analysis helpers
# -----------------------------
function mag_spectrum(x)
    X = fft(x .* hann(length(x)))
    mag = abs.(X)[1:div(end,2)]
    mag ./ maximum(mag)
end

function find_peaks(spec, freqs; threshold_db=-40, min_sep=30.0)
    db = 20 .* log10.(spec .+ 1e-12)
    peaks = Tuple{Float64,Float64}[]  # (freq, db)
    for i in 3:length(db)-2
        if db[i] > threshold_db && freqs[i] > 50
            if db[i] > db[i-1] && db[i] > db[i+1] &&
               db[i] > db[i-2] && db[i] > db[i+2]
                # Check minimum separation from existing peaks
                too_close = false
                for (pf, _) in peaks
                    if abs(freqs[i] - pf) < min_sep
                        too_close = true
                        break
                    end
                end
                if !too_close
                    push!(peaks, (freqs[i], db[i]))
                end
            end
        end
    end
    sort(peaks, by=x->x[1])
end

function analyze_inharmonicity(peaks, f0)
    if length(peaks) < 3
        return Float64[]
    end
    cents = Float64[]
    for (i, (pf, _)) in enumerate(peaks[1:min(8, length(peaks))])
        expected = i * f0
        if pf > 0 && expected > 0
            c = 1200 * log2(pf / expected)
            push!(cents, c)
        end
    end
    cents
end

# -----------------------------
# Main
# -----------------------------
println("\nSingle-Oscillator Inharmonicity Test")
println("=====================================")
println("f0 = $f0 Hz, β = $beta")
println()

# Reference
y_ref = rpm_reference(omega, beta, N)[discard:end]
spec_ref = mag_spectrum(y_ref)
freqs = fs .* (0:length(spec_ref)-1) ./ length(y_ref)
peaks_ref = find_peaks(spec_ref, freqs)

println("Reference partials:")
for (i, (pf, db)) in enumerate(peaks_ref[1:min(6, length(peaks_ref))])
    println("  $(i): $(round(pf, digits=1)) Hz ($(round(db, digits=1)) dB)")
end
println()

# Test methods
methods = [
    ("Curvature FM", (B) -> rpm_curvature_fm(omega, beta, N; B=B)),
    ("Phase Warp", (B) -> rpm_phase_warp(omega, beta, N; warp=B*10)),
    ("Allpass FreqMod", (B) -> rpm_allpass_freq_mod(omega, beta, N; B=B)),
    ("Energy Stretch", (B) -> rpm_energy_stretch(omega, beta, N; B=B)),
]

for (name, func) in methods
    println("$name:")
    for B in [-0.1, 0.1, 0.3]
        y = func(B)[discard:end]
        spec = mag_spectrum(y)
        peaks = find_peaks(spec, freqs)
        cents = analyze_inharmonicity(peaks, f0)
        label = B > 0 ? "tight" : "loose"
        print("  B=$(B) ($label): ")
        for (i, c) in enumerate(cents[1:min(6, length(cents))])
            print("H$i=$(round(c, sigdigits=2))¢ ")
        end
        println()
    end
    println()
end

# -----------------------------
# Plotting
# -----------------------------

p1 = plot(title="Reference", xlabel="Hz", ylabel="dB",
          xlim=(0, f0*10), ylim=(-60, 0), legend=false)
plot!(p1, freqs, 20 .* log10.(spec_ref .+ 1e-9), color=:blue)
for h in 1:8
    vline!(p1, [h*f0], color=:red, alpha=0.3, linestyle=:dash)
end

p2 = plot(title="Curvature FM B=0.2", xlabel="Hz", ylabel="dB",
          xlim=(0, f0*10), ylim=(-60, 0), legend=false)
y = rpm_curvature_fm(omega, beta, N; B=0.2)[discard:end]
spec = mag_spectrum(y)
plot!(p2, freqs, 20 .* log10.(spec .+ 1e-9), color=:orange)
for h in 1:8
    vline!(p2, [h*f0], color=:red, alpha=0.3, linestyle=:dash)
end

p3 = plot(title="Allpass FreqMod B=0.2", xlabel="Hz", ylabel="dB",
          xlim=(0, f0*10), ylim=(-60, 0), legend=false)
y = rpm_allpass_freq_mod(omega, beta, N; B=0.2)[discard:end]
spec = mag_spectrum(y)
plot!(p3, freqs, 20 .* log10.(spec .+ 1e-9), color=:green)
for h in 1:8
    vline!(p3, [h*f0], color=:red, alpha=0.3, linestyle=:dash)
end

p4 = plot(title="Energy Stretch B=0.2", xlabel="Hz", ylabel="dB",
          xlim=(0, f0*10), ylim=(-60, 0), legend=false)
y = rpm_energy_stretch(omega, beta, N; B=0.2)[discard:end]
spec = mag_spectrum(y)
plot!(p4, freqs, 20 .* log10.(spec .+ 1e-9), color=:purple)
for h in 1:8
    vline!(p4, [h*f0], color=:red, alpha=0.3, linestyle=:dash)
end

final_plot = plot(p1, p2, p3, p4, layout=(2, 2), size=(1400, 900))

outfile = tempname() * "_rpm_single_osc.png"
savefig(final_plot, outfile)
run(`open $outfile`)

println("Image saved to: $outfile")
println("\nUsage: julia rpm_single_osc_inharm.jl [f0] [beta]")
