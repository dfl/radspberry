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
# CURVATURE-BASED INHARMONICITY - REFINED
# =====================================================
#
# Key insight: curvature (2nd derivative) scales with h²
# for harmonic h. By modulating frequency based on
# curvature, we get differential stretch.
#
# Refinements:
# - Gentler coefficients
# - Better smoothing to avoid instability
# - Bipolar curvature tracking
# =====================================================

# Reference
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
# Refined curvature-based inharmonicity
#
# B: inharmonicity coefficient (small values!)
#    B > 0: tight (higher partials sharpen)
#    B < 0: loose (higher partials flatten)
#
# smooth: smoothing coefficient (0.001-0.1)
# -----------------------------
function rpm_curvature(omega, beta, N; alpha=0.001, B=0.0, smooth=0.01)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    curv_smooth = 0.0
    curv_rms = 0.1  # Running RMS of curvature for normalization

    for n in 4:N
        n1, n2, n3 = n-1, n-2, n-3

        # Second derivative (curvature)
        curv = y[n1] - 2*y[n2] + y[n3]

        # Track RMS of curvature for normalization
        curv_rms += 0.001 * (sqr(curv) - curv_rms)
        curv_norm = sqrt(max(curv_rms, 0.0001))

        # Smooth the normalized curvature
        curv_smooth += smooth * (curv / curv_norm - curv_smooth)

        # Frequency modulation: base + curvature contribution
        # Curvature squared gives h⁴ scaling (strong differential)
        # Linear curvature gives h² scaling (moderate differential)
        freq_mod = 1.0 + B * sqr(curv_smooth)
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
# Variant: signed curvature for bipolar control
# -----------------------------
function rpm_curvature_signed(omega, beta, N; alpha=0.001, B=0.0, smooth=0.02)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    curv_smooth = 0.0

    for n in 4:N
        n1, n2, n3 = n-1, n-2, n-3

        # Second derivative
        curv = y[n1] - 2*y[n2] + y[n3]

        # Smooth with sign preserved
        curv_smooth += smooth * (curv - curv_smooth)

        # Use absolute value for frequency mod (always positive freq)
        freq_mod = 1.0 + B * abs(curv_smooth)
        phase += omega * freq_mod

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
# Variant: envelope-following curvature
# Track envelope of curvature for smoother control
# -----------------------------
function rpm_curvature_env(omega, beta, N; alpha=0.001, B=0.0, attack=0.1, release=0.01)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    curv_env = 0.0

    for n in 4:N
        n1, n2, n3 = n-1, n-2, n-3

        curv = abs(y[n1] - 2*y[n2] + y[n3])

        # Envelope follower
        if curv > curv_env
            curv_env += attack * (curv - curv_env)
        else
            curv_env += release * (curv - curv_env)
        end

        freq_mod = 1.0 + B * curv_env
        phase += omega * freq_mod

        y_tpt = 0.5 * (y[n1] + y[n2])
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))
        u = beta * y_tpt / rms

        y[n] = sin(phase + u)
    end
    y
end

# Analysis
function mag_spectrum(x)
    X = fft(x .* hann(length(x)))
    mag = abs.(X)[1:div(end,2)]
    mag ./ maximum(mag)
end

function find_peaks(spec, freqs; threshold_db=-40, min_sep=30.0)
    db = 20 .* log10.(spec .+ 1e-12)
    peaks = Tuple{Float64,Float64}[]
    for i in 3:length(db)-2
        if db[i] > threshold_db && freqs[i] > 50
            if db[i] > db[i-1] && db[i] > db[i+1] &&
               db[i] > db[i-2] && db[i] > db[i+2]
                too_close = any(abs(freqs[i] - pf) < min_sep for (pf, _) in peaks)
                if !too_close
                    push!(peaks, (freqs[i], db[i]))
                end
            end
        end
    end
    sort(peaks, by=x->x[1])
end

# Main
println("\nRefined Curvature-Based Inharmonicity")
println("=====================================")
println("f0 = $f0 Hz, β = $beta")
println()

y_ref = rpm_reference(omega, beta, N)[discard:end]
spec_ref = mag_spectrum(y_ref)
freqs = fs .* (0:length(spec_ref)-1) ./ length(y_ref)

println("Reference partials:")
peaks_ref = find_peaks(spec_ref, freqs)
for (i, (pf, _)) in enumerate(peaks_ref[1:min(8, length(peaks_ref))])
    expected = i * f0
    cents = 1200 * log2(pf / expected)
    println("  H$i: $(round(pf, digits=1)) Hz ($(round(cents, sigdigits=2))¢ from harmonic)")
end
println()

# Test refined curvature with smaller B values
println("Curvature (squared) - small B values:")
for B in [0.01, 0.02, 0.05, 0.1]
    y = rpm_curvature(omega, beta, N; B=B)[discard:end]
    spec = mag_spectrum(y)
    peaks = find_peaks(spec, freqs)
    print("  B=$B: ")
    for (i, (pf, _)) in enumerate(peaks[1:min(6, length(peaks))])
        cents = 1200 * log2(pf / (i * f0))
        print("H$i=$(round(cents, sigdigits=2))¢ ")
    end
    println()
end
println()

println("Curvature (envelope) - smoother:")
for B in [0.05, 0.1, 0.2]
    y = rpm_curvature_env(omega, beta, N; B=B)[discard:end]
    spec = mag_spectrum(y)
    peaks = find_peaks(spec, freqs)
    print("  B=$B: ")
    for (i, (pf, _)) in enumerate(peaks[1:min(6, length(peaks))])
        cents = 1200 * log2(pf / (i * f0))
        print("H$i=$(round(cents, sigdigits=2))¢ ")
    end
    println()
end
println()

# Negative B (loose)
println("Negative B (loose partials):")
for B in [-0.02, -0.05, -0.1]
    y = rpm_curvature(omega, beta, N; B=B)[discard:end]
    spec = mag_spectrum(y)
    peaks = find_peaks(spec, freqs)
    print("  B=$B: ")
    for (i, (pf, _)) in enumerate(peaks[1:min(6, length(peaks))])
        cents = 1200 * log2(pf / (i * f0))
        print("H$i=$(round(cents, sigdigits=2))¢ ")
    end
    println()
end

# Plots
p1 = plot(title="Reference", xlim=(0, f0*10), ylim=(-60, 0), legend=false)
plot!(p1, freqs, 20 .* log10.(spec_ref .+ 1e-9))
for h in 1:8; vline!(p1, [h*f0], color=:red, alpha=0.3, linestyle=:dash); end

p2 = plot(title="Curvature B=0.05", xlim=(0, f0*10), ylim=(-60, 0), legend=false)
y = rpm_curvature(omega, beta, N; B=0.05)[discard:end]
plot!(p2, freqs, 20 .* log10.(mag_spectrum(y) .+ 1e-9), color=:orange)
for h in 1:8; vline!(p2, [h*f0], color=:red, alpha=0.3, linestyle=:dash); end

p3 = plot(title="Curvature B=-0.05 (loose)", xlim=(0, f0*10), ylim=(-60, 0), legend=false)
y = rpm_curvature(omega, beta, N; B=-0.05)[discard:end]
plot!(p3, freqs, 20 .* log10.(mag_spectrum(y) .+ 1e-9), color=:blue)
for h in 1:8; vline!(p3, [h*f0], color=:red, alpha=0.3, linestyle=:dash); end

p4 = plot(title="Curvature Env B=0.1", xlim=(0, f0*10), ylim=(-60, 0), legend=false)
y = rpm_curvature_env(omega, beta, N; B=0.1)[discard:end]
plot!(p4, freqs, 20 .* log10.(mag_spectrum(y) .+ 1e-9), color=:green)
for h in 1:8; vline!(p4, [h*f0], color=:red, alpha=0.3, linestyle=:dash); end

final_plot = plot(p1, p2, p3, p4, layout=(2, 2), size=(1400, 900))
outfile = tempname() * "_rpm_curvature.png"
savefig(final_plot, outfile)
run(`open $outfile`)

println("\nImage saved to: $outfile")
