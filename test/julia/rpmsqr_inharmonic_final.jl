using DSP, FFTW, Plots
gr()

fs      = 48000.0
f0      = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 110.0
beta    = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : -1.5
B       = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 0.0
omega   = 2π * f0 / fs
N       = 16384
discard = 4096

sqr(y) = y * y

# =====================================================
# RPM with INHARMONICITY
# =====================================================
#
# Reference implementation for power-normalized RPM
# with independent inharmonicity control.
#
# Parameters:
#   omega: carrier frequency (rad/sample)
#   beta:  feedback strength (timbre control)
#          positive = linear feedback, negative = squared
#   B:     inharmonicity coefficient
#          B > 0: tight (higher partials sharpen)
#          B < 0: loose (higher partials flatten)
#          Typical range: -0.03 to +0.03
#   alpha: power tracking smoothing (default 0.001)
#
# How it works:
#   Curvature (2nd derivative) scales as h² for harmonic h.
#   By modulating carrier frequency with curvature²,
#   higher harmonics get more frequency shift.
# =====================================================

function rpmsqr_inharmonic(omega, beta, N; alpha=0.001, B=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    curv_rms = 0.01

    for n in 4:N
        n1, n2, n3 = n-1, n-2, n-3

        # Curvature tracking (normalized for beta independence)
        curv = y[n1] - 2*y[n2] + y[n3]
        curv_rms += 0.001 * (sqr(curv) - curv_rms)
        curv_normalized = curv / sqrt(max(curv_rms, 1e-6))

        # Frequency modulation from curvature
        freq_mod = 1.0 + B * sqr(curv_normalized)
        phase += omega * freq_mod

        # Power-normalized feedback
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)

        if beta < 0
            # Squared feedback (odd harmonics)
            u = beta * (ysq_avg / max(rms_sq, 0.01) * 0.5 - 0.5)
        else
            # Linear feedback (all harmonics)
            y_tpt = 0.5 * (y[n1] + y[n2])
            rms = sqrt(max(rms_sq, 0.01))
            u = beta * y_tpt / rms
        end

        y[n] = sin(phase + u)
    end
    y
end

# Convenience wrapper for squared feedback version
function rpmsqr_power_norm_inharmonic(omega, beta, N; alpha=0.001, B=0.0)
    rpmsqr_inharmonic(omega, -abs(beta), N; alpha=alpha, B=B)
end

# Analysis
function mag_spectrum(x)
    X = fft(x .* hann(length(x)))
    mag = abs.(X)[1:div(end,2)]
    mag ./ maximum(mag)
end

function find_peaks(spec, freqs; threshold_db=-50)
    db = 20 .* log10.(spec .+ 1e-12)
    peaks = Tuple{Float64,Float64}[]
    for i in 3:length(db)-2
        if db[i] > threshold_db && freqs[i] > 50
            if db[i] > db[i-1] && db[i] > db[i+1] &&
               db[i] > db[i-2] && db[i] > db[i+2]
                too_close = any(abs(freqs[i] - pf) < 30.0 for (pf, _) in peaks)
                if !too_close
                    push!(peaks, (freqs[i], db[i]))
                end
            end
        end
    end
    sort(peaks, by=x->x[1])
end

# Main
println("\n" * "="^50)
println("RPM with Inharmonicity - Reference Implementation")
println("="^50)
println("f0 = $f0 Hz, β = $beta, B = $B")
println()

y = rpmsqr_inharmonic(omega, beta, N; B=B)[discard:end]
spec = mag_spectrum(y)
freqs = fs .* (0:length(spec)-1) ./ length(y)
peaks = find_peaks(spec, freqs)

println("Partials:")
for (i, (pf, db)) in enumerate(peaks[1:min(8, length(peaks))])
    expected = i * f0
    cents = 1200 * log2(pf / expected)
    dir = cents > 5 ? "↑" : (cents < -5 ? "↓" : "·")
    println("  H$i: $(round(pf, digits=1)) Hz  $(round(cents, sigdigits=2))¢  $dir")
end

# Compare harmonic vs inharmonic
println("\n" * "-"^50)
println("Comparison: B=0 (harmonic) vs B=$B")
println("-"^50)

y_harm = rpmsqr_inharmonic(omega, beta, N; B=0.0)[discard:end]
spec_harm = mag_spectrum(y_harm)
peaks_harm = find_peaks(spec_harm, freqs)

print("Harmonic:    ")
for (i, (pf, _)) in enumerate(peaks_harm[1:min(6, length(peaks_harm))])
    print("$(round(pf, digits=0)) ")
end
println()

print("B=$B:  ")
for (i, (pf, _)) in enumerate(peaks[1:min(6, length(peaks))])
    print("$(round(pf, digits=0)) ")
end
println()

# Plot
p = plot(
    title="RPM Inharmonic: β=$beta, B=$B",
    xlabel="Frequency (Hz)",
    ylabel="Magnitude (dB)",
    xlim=(0, f0 * 12),
    ylim=(-60, 0),
    legend=:topright,
    size=(1000, 500)
)

plot!(p, freqs, 20 .* log10.(spec_harm .+ 1e-9),
      label="B=0 (harmonic)", alpha=0.5, color=:gray)
plot!(p, freqs, 20 .* log10.(spec .+ 1e-9),
      label="B=$B", linewidth=1.5, color=:blue)

for h in 1:10
    vline!(p, [h * f0], color=:red, alpha=0.2, linestyle=:dash, label=false)
end

outfile = tempname() * "_rpm_inharmonic.png"
savefig(p, outfile)
run(`open $outfile`)

println("\nImage saved to: $outfile")
println()
println("Usage: julia rpmsqr_inharmonic_final.jl [f0] [beta] [B]")
println("       julia rpmsqr_inharmonic_final.jl 110 -1.5 0.02")
println("       julia rpmsqr_inharmonic_final.jl 110 -1.5 -0.02")
