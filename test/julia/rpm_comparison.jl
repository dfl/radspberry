using DSP, FFTW, Plots
gr()  # ensure native window

# -----------------------------
# Global parameters
# -----------------------------
fs      = 48000.0
beta    = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 1.5
f0      = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 220.0
omega   = 2π * f0 / fs
N       = 8192
discard = 2048

# -----------------------------
# Oscillators
# -----------------------------

function rpm_naive(omega, beta, N)
    y = zeros(Float64, N)
    phase = 0.0
    for n in 2:N
        phase += omega
        y[n] = sin(phase + beta * y[n-1])
    end
    y
end

function rpm_tpt(omega, beta, N)
    y = zeros(Float64, N)
    phase = 0.0
    for n in 2:N
        phase += omega
        u = beta * 0.5 * (y[n-1] + y[n-2 ≥ 1 ? n-2 : 1])
        y[n] = sin(phase + u)
    end
    y
end

function rpm_zdf(omega, beta, N; iters=2)
    y = zeros(Float64, N)
    phase = 0.0
    for n in 2:N
        phase += omega
        yn = y[n-1]  # initial guess
        for _ in 1:iters
            s = sin(phase + beta * yn)
            c = cos(phase + beta * yn)
            yn -= (yn - s) / (1 - beta * c)
        end
        y[n] = yn
    end
    y
end

function rpm_zdf_bisect(omega, beta, N; iters=16)
    y = zeros(Float64, N)
    phase = 0.0
    for n in 2:N
        phase += omega
        # Bisection on f(y) = y - sin(phase + beta*y)
        lo, hi = -1.0, 1.0
        for _ in 1:iters
            mid = 0.5 * (lo + hi)
            f_mid = mid - sin(phase + beta * mid)
            if f_mid > 0
                hi = mid
            else
                lo = mid
            end
        end
        y[n] = 0.5 * (lo + hi)
    end
    y
end

# -----------------------------
# Generate signals
# -----------------------------

y_naive = rpm_naive(omega, beta, N)
y_tpt   = rpm_tpt(omega, beta, N)
y_zdf   = rpm_zdf_bisect(omega, beta, N)

# remove transient
y_naive = y_naive[discard:end]
y_tpt   = y_tpt[discard:end]
y_zdf   = y_zdf[discard:end]

# -----------------------------
# FFT helper
# -----------------------------

function mag_spectrum(x)
    X = fft(x .* hann(length(x)))
    mag = abs.(X)[1:div(end,2)]
    mag ./ maximum(mag)
end

# Compute spectra
spec_naive = mag_spectrum(y_naive)
spec_tpt   = mag_spectrum(y_tpt)
spec_zdf   = mag_spectrum(y_zdf)

freqs = fs .* (0:length(spec_naive)-1) ./ length(y_naive)

# -----------------------------
# Plots
# -----------------------------

# Time-domain plot
p1 = plot(
    y_naive[1:1000],
    label="Naïve",
    alpha=0.7,
    title="Time Domain (β = $beta, f0 = $f0 Hz)",
    xlabel="Samples",
    ylabel="Amplitude"
)
plot!(p1, y_tpt[1:1000], label="TPT", alpha=0.7)
plot!(p1, y_zdf[1:1000], label="ZDF (bisect)", alpha=0.7)

# Frequency-domain plot
p2 = plot(
    freqs,
    20 .* log10.(spec_naive .+ 1e-9),
    label="Naïve",
    xlim=(0, 5000),
    ylim=(-80, 0),
    xlabel="Frequency (Hz)",
    ylabel="Magnitude (dB)",
    title="Magnitude Spectrum"
)
plot!(p2, freqs, 20 .* log10.(spec_tpt .+ 1e-9), label="TPT")
plot!(p2, freqs, 20 .* log10.(spec_zdf .+ 1e-9), label="ZDF (bisect)")

final_plot = plot(p1, p2, layout=(2,1), size=(900,700))

# Save and open
outfile = tempname() * "_rpm.png"
savefig(final_plot, outfile)
run(`open $outfile`)

println("\nRPM Comparison")
println("==============")
println("β = $beta, f0 = $f0 Hz")
println("")
println("Usage: julia rpm_comparison.jl [beta] [f0]")
println("       julia rpm_comparison.jl 1.5 440")
println("")
println("Image saved to: $outfile")