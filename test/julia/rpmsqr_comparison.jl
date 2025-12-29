using DSP, FFTW, Plots
gr()  # ensure native window

# -----------------------------
# Global parameters
# -----------------------------
fs      = 48000.0
beta    = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : -1.5  # negative for squaring
f0      = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 220.0
omega   = 2π * f0 / fs
N       = 8192
discard = 2048

# -----------------------------
# Squaring function (unsigned y² for odd harmonics)
# -----------------------------

sqr(y) = y * y

# -----------------------------
# Oscillators with unsigned squaring
# -----------------------------

# Naive with squaring
function rpmsqr_naive(omega, beta, N)
    y = zeros(Float64, N)
    phase = 0.0
    for n in 2:N
        phase += omega
        y[n] = sin(phase + beta * sqr(y[n-1]))
    end
    y
end

# TPT: square then average (2-point, DC-compensated)
function rpmsqr_tpt_2pt(omega, beta, N)
    y = zeros(Float64, N)
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2 = n-1, max(n-2, 1)
        u = beta * 0.5 * (sqr(y[n1]) + sqr(y[n2]) - 1.0)
        y[n] = sin(phase + u)
    end
    y
end

# TPT: square then average (3-point, DC-compensated)
function rpmsqr_tpt_3pt(omega, beta, N)
    y = zeros(Float64, N)
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2, n3 = n-1, max(n-2, 1), max(n-3, 1)
        u = beta * (sqr(y[n1]) + sqr(y[n2]) + sqr(y[n3]) - 1.5) / 3.0
        y[n] = sin(phase + u)
    end
    y
end

# TPT: square then average (4-point, DC-compensated)
function rpmsqr_tpt_4pt(omega, beta, N)
    y = zeros(Float64, N)
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2, n3, n4 = n-1, max(n-2, 1), max(n-3, 1), max(n-4, 1)
        u = beta * (sqr(y[n1]) + sqr(y[n2]) + sqr(y[n3]) + sqr(y[n4]) - 2.0) / 4.0
        y[n] = sin(phase + u)
    end
    y
end

# -----------------------------
# Generate signals
# -----------------------------

y_2pt = rpmsqr_tpt_2pt(omega, beta, N)
y_3pt = rpmsqr_tpt_3pt(omega, beta, N)
y_4pt = rpmsqr_tpt_4pt(omega, beta, N)

# remove transient
y_2pt = y_2pt[discard:end]
y_3pt = y_3pt[discard:end]
y_4pt = y_4pt[discard:end]

# -----------------------------
# FFT helper
# -----------------------------

function mag_spectrum(x)
    X = fft(x .* hann(length(x)))
    mag = abs.(X)[1:div(end,2)]
    mag ./ maximum(mag)
end

# Compute spectra
spec_2pt = mag_spectrum(y_2pt)
spec_3pt = mag_spectrum(y_3pt)
spec_4pt = mag_spectrum(y_4pt)

freqs = fs .* (0:length(spec_2pt)-1) ./ length(y_2pt)

# -----------------------------
# Plots
# -----------------------------

# Time-domain plot
p1 = plot(
    y_2pt[1:1000],
    label="2-point",
    alpha=0.8,
    linewidth=2,
    title="RPM Squaring (y²) sqr→avg - Time Domain (β = $beta, f0 = $f0 Hz)",
    xlabel="Samples",
    ylabel="Amplitude",
    legend=:topright
)
plot!(p1, y_3pt[1:1000], label="3-point", alpha=0.7)
plot!(p1, y_4pt[1:1000], label="4-point", alpha=0.7)

# Frequency-domain plot
p2 = plot(
    freqs,
    20 .* log10.(spec_2pt .+ 1e-9),
    label="2-point",
    linewidth=2,
    xlim=(0, 5000),
    ylim=(-80, 0),
    xlabel="Frequency (Hz)",
    ylabel="Magnitude (dB)",
    title="Magnitude Spectrum",
    legend=:topright
)
plot!(p2, freqs, 20 .* log10.(spec_3pt .+ 1e-9), label="3-point")
plot!(p2, freqs, 20 .* log10.(spec_4pt .+ 1e-9), label="4-point")

final_plot = plot(p1, p2, layout=(2,1), size=(1000,750))

# Save and open
outfile = tempname() * "_rpmsqr.png"
savefig(final_plot, outfile)
run(`open $outfile`)

println("\nRPM Squaring sqr→avg Comparison (y²)")
println("====================================")
println("β = $beta, f0 = $f0 Hz")
println("")
println("Usage: julia rpmsqr_comparison.jl [beta] [f0]")
println("       julia rpmsqr_comparison.jl -1.5 440")
println("")
println("Methods (all sqr→avg):")
println("  2-point   - (y[n-1]² + y[n-2]²) / 2")
println("  3-point   - (y[n-1]² + y[n-2]² + y[n-3]²) / 3")
println("  4-point   - (y[n-1]² + y[n-2]² + y[n-3]² + y[n-4]²) / 4")
println("")
println("Image saved to: $outfile")
