using DSP, FFTW, Plots
gr()

fs      = 48000.0
f0      = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 110.0
beta    = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 1.5
B_val   = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 0.0
omega   = 2π * f0 / fs
N       = 16384
discard = 4096

sqr(y) = y * y

# =====================================================
# DECOUPLED INHARMONICITY
# =====================================================
# Beta: controls RPM feedback strength (timbre)
# B: controls inharmonicity (partial stretch)
#
# Key: normalize curvature by signal RMS so that
# inharmonicity is independent of beta
# =====================================================

function rpm_decoupled(omega, beta, N; alpha=0.001, B=0.0)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0

    # Curvature tracking with normalization
    curv_rms = 0.01  # Track curvature magnitude

    for n in 4:N
        n1, n2, n3 = n-1, n-2, n-3

        # Curvature (2nd derivative) - scales with h² for harmonic h
        curv = y[n1] - 2*y[n2] + y[n3]

        # Track curvature RMS for normalization
        curv_rms += 0.001 * (sqr(curv) - curv_rms)
        curv_norm = sqrt(max(curv_rms, 1e-6))

        # Normalized curvature (independent of signal level/beta)
        curv_normalized = curv / curv_norm

        # Frequency modulation based on normalized curvature²
        # This creates h⁴ scaling for differential stretch
        freq_mod = 1.0 + B * sqr(curv_normalized)
        phase += omega * freq_mod

        # Standard RPM feedback (controlled by beta only)
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

function find_peaks(spec, freqs; threshold_db=-50, min_sep=30.0)
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

function show_partials(y, freqs, f0, label)
    spec = mag_spectrum(y)
    peaks = find_peaks(spec, freqs)
    print("  $label: ")
    for (i, (pf, _)) in enumerate(peaks[1:min(6, length(peaks))])
        cents = 1200 * log2(pf / (i * f0))
        print("H$i=$(round(cents, sigdigits=2))¢ ")
    end
    println()
end

# Main
println("\nDecoupled Beta/Inharmonicity Test")
println("==================================")
println("f0 = $f0 Hz")
println()

y_ref = rpm_decoupled(omega, 1.5, N; B=0.0)[discard:end]
spec_ref = mag_spectrum(y_ref)
freqs = fs .* (0:length(spec_ref)-1) ./ length(y_ref)

# Test: vary beta with fixed B
println("Varying beta (B=0.02 fixed):")
for β in [0.5, 1.0, 1.5, 2.0]
    y = rpm_decoupled(omega, β, N; B=0.02)[discard:end]
    show_partials(y, freqs, f0, "β=$β")
end
println()

# Test: vary B with fixed beta
println("Varying B (β=1.5 fixed):")
for B in [0.0, 0.01, 0.02, 0.05]
    y = rpm_decoupled(omega, 1.5, N; B=B)[discard:end]
    show_partials(y, freqs, f0, "B=$B")
end
println()

# Test negative B
println("Negative B (loose, β=1.5):")
for B in [-0.01, -0.02, -0.05]
    y = rpm_decoupled(omega, 1.5, N; B=B)[discard:end]
    show_partials(y, freqs, f0, "B=$B")
end

# Plots - 2x3 grid showing beta and B variations
plots = []

# Row 1: varying beta
for (i, β) in enumerate([0.5, 1.5, 2.5])
    p = plot(title="β=$β, B=0.02", xlim=(0, f0*10), ylim=(-60, 0),
             xlabel=i==2 ? "" : "", legend=false, titlefontsize=10)
    y = rpm_decoupled(omega, β, N; B=0.02)[discard:end]
    plot!(p, freqs, 20 .* log10.(mag_spectrum(y) .+ 1e-9), color=:blue)
    for h in 1:8; vline!(p, [h*f0], color=:red, alpha=0.2, linestyle=:dash); end
    push!(plots, p)
end

# Row 2: varying B
for (i, B) in enumerate([0.0, 0.02, 0.05])
    p = plot(title="β=1.5, B=$B", xlim=(0, f0*10), ylim=(-60, 0),
             xlabel="Hz", legend=false, titlefontsize=10)
    y = rpm_decoupled(omega, 1.5, N; B=B)[discard:end]
    plot!(p, freqs, 20 .* log10.(mag_spectrum(y) .+ 1e-9), color=:orange)
    for h in 1:8; vline!(p, [h*f0], color=:red, alpha=0.2, linestyle=:dash); end
    push!(plots, p)
end

final_plot = plot(plots..., layout=(2, 3), size=(1400, 800))
outfile = tempname() * "_rpm_decoupled.png"
savefig(final_plot, outfile)
run(`open $outfile`)

println("\nImage saved to: $outfile")
println("\nUsage: julia rpm_decoupled.jl [f0] [beta] [B]")
